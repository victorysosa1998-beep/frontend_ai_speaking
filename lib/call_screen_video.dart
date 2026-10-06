import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'UpgradePage.dart';
import 'app_brand.dart';
import 'ovie_ui.dart';
import 'secrets.dart';

/// Video call with Buddy or Missy.
///
/// The AI is shown full-screen. Your camera sits in a draggable picture-in-
/// picture window and, every ~10 s while the call is live, a frame is sent to
/// the backend so the AI can react to what it sees.
///
/// Billing, quota and LiveKit handling match [CallScreen] (call_screen.dart).
class VideoCallScreen extends StatefulWidget {
  final String voice;
  final String vibe;
  final String imagePath;
  const VideoCallScreen({
    super.key,
    required this.voice,
    required this.vibe,
    required this.imagePath,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

enum _NetQuality { good, poor, lost }

double _clampD(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

int _asInt(dynamic v) => v is num ? v.toInt() : 0;

class _VideoCallScreenState extends State<VideoCallScreen>
    with SingleTickerProviderStateMixin {
  static const _api = 'https://web-production-6c359.up.railway.app';
  static const _secondsPerCredit = 12;
  static const _pipSize = Size(112, 150);
  static const _pipSizeLarge = Size(168, 224);

  // ── LiveKit ────────────────────────────────────────────────────────────────
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true; // video calls default to speaker
  bool _exited = false;
  bool _hasError = false;
  bool _micDenied = false;
  String _caption = '';
  String? _activeEmoji;

  // Audio levels are notifiers so only the small widgets that show them rebuild.
  final ValueNotifier<double> _aiLevel = ValueNotifier(0);
  final ValueNotifier<double> _userLevel = ValueNotifier(0);
  double _aiSmooth = 0;

  // ── Timers ─────────────────────────────────────────────────────────────────
  Timer? _statsTimer;
  Timer? _durationTimer;
  Timer? _netTimer;
  Timer? _visionTimer;
  Timer? _visionToastTimer;
  Timer? _emojiTimer;
  int _seconds = 0;

  // ── Credits ────────────────────────────────────────────────────────────────
  String _deviceId = '';
  int _totalSecondsLeft = 0;
  bool _quotaExhausted = false;
  bool _endingCall = false;
  int _lastSavedSeconds = 0;

  // ── Network ────────────────────────────────────────────────────────────────
  _NetQuality _net = _NetQuality.good;

  // ── Camera / PiP ───────────────────────────────────────────────────────────
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  CameraController? _camera;
  bool _cameraReady = false;
  bool _cameraEnabled = true;
  bool _cameraDenied = false;
  bool _sendingFrame = false;
  String? _visionComment;
  Offset? _pipOffset;
  bool _pipLarge = false;
  bool _pipDragging = false;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  String get _aiName => widget.voice == 'male' ? 'Buddy' : 'Missy';
  int get _creditsToSeconds => _secondsPerCredit;

  @override
  void initState() {
    super.initState();
    _caption = 'Calling $_aiName…';
    _loadDeviceIdThenConnect();
  }

  void _log(String tag, Object? msg) => debugPrint('[VideoCall|$tag] $msg');

  // ══════════════════════════════════════════════════════════════════════════
  // Camera
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _initCamera({int? index}) async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _cameraDenied = true;
            _cameraEnabled = false;
          });
        }
        return;
      }
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _cameraEnabled = false);
        return;
      }
      if (index != null) {
        _cameraIndex = index;
      } else {
        final front = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        _cameraIndex = front >= 0 ? front : 0;
      }
      final old = _camera;
      if (mounted) setState(() => _cameraReady = false);
      await old?.dispose();

      final controller = CameraController(
        _cameras[_cameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _camera = controller;
      await controller.initialize();
      if (!mounted || _exited) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraReady = true;
        _cameraDenied = false;
      });
    } catch (e) {
      _log('CAMERA', 'init failed: $e');
      if (mounted) setState(() => _cameraEnabled = false);
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    await _initCamera(index: (_cameraIndex + 1) % _cameras.length);
  }

  void _toggleCamera() {
    if (_cameraDenied) {
      openAppSettings();
      return;
    }
    setState(() => _cameraEnabled = !_cameraEnabled);
    if (_cameraEnabled && !_cameraReady) _initCamera();
  }

  void _startVisionLoop() {
    _visionTimer?.cancel();
    // First frame after the camera has had a moment to settle.
    _visionTimer = Timer(const Duration(seconds: 4), () {
      _captureAndSend();
      _visionTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _captureAndSend(),
      );
    });
  }

  Future<void> _captureAndSend() async {
    final cam = _camera;
    if (_exited || !_isConnected || !_cameraEnabled || !_cameraReady) return;
    if (cam == null || !cam.value.isInitialized) return;
    if (cam.value.isTakingPicture || _sendingFrame) return;
    _sendingFrame = true;
    try {
      final file = await cam.takePicture();
      final bytes = await file.readAsBytes();
      if (bytes.length > 500) await _sendFrame(bytes);
    } catch (e) {
      _log('VISION', 'capture failed: $e');
    } finally {
      _sendingFrame = false;
    }
  }

  Future<void> _sendFrame(Uint8List bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('sympy_user_id') ?? '';
      if (userId.isEmpty) return;
      final res = await http
          .post(
            Uri.parse('$_api/call_vision'),
            headers: {
              'Content-Type': 'application/octet-stream',
              'X-API-KEY': AppSecrets.appApiKey,
              'X-User-Id': userId,
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return;
      final comment = (jsonDecode(res.body)['comment'] as String?) ?? '';
      if (comment.isEmpty || !mounted || _exited) return;

      setState(() => _visionComment = comment);
      _visionToastTimer?.cancel();
      _visionToastTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _visionComment = null);
      });

      // Hand the observation to the agent so it can say it out loud.
      final room = _room;
      if (room != null && _isConnected) {
        await room.localParticipant?.publishData(
          utf8.encode('VISION_COMMENT|$comment'),
          reliable: true,
        );
      }
    } catch (e) {
      _log('VISION', 'send failed: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Device id + quota (same rules as the voice call)
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _loadDeviceIdThenConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
    String stored;
    if (firebaseUid != null) {
      stored = 'user_$firebaseUid';
      await prefs.setString('sympy_user_id', stored);
    } else {
      var existing = prefs.getString('sympy_user_id');
      if (existing == null) {
        final rand = DateTime.now().millisecondsSinceEpoch.toString();
        existing = 'user_${rand.substring(rand.length - 10)}';
        await prefs.setString('sympy_user_id', existing);
      }
      stored = existing;
    }
    if (mounted) setState(() => _deviceId = stored);
    await _flushPendingSeconds(prefs, stored);
    await _checkQuotaBeforeCall(stored);
  }

  Future<void> _flushPendingSeconds(
    SharedPreferences prefs,
    String deviceId,
  ) async {
    final pending = prefs.getInt('pending_call_seconds') ?? 0;
    final pendingDevice = prefs.getString('pending_call_device_id') ?? '';
    if (pending <= 0 || pendingDevice.isEmpty) return;
    try {
      final res = await http
          .post(
            Uri.parse('$_api/call_ended?duration_seconds=$pending'),
            headers: {
              'X-API-KEY': AppSecrets.appApiKey,
              'X-Device-Id': pendingDevice,
            },
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        await prefs.remove('pending_call_seconds');
        await prefs.remove('pending_call_device_id');
      }
    } catch (e) {
      _log('QUOTA', 'flush failed: $e');
    }
  }

  void _applyQuota(Map<String, dynamic> data) {
    final free = _asInt(data['seconds_remaining']);
    final credits = _asInt(data['purchased_credits']);
    if (!mounted) return;
    setState(() => _totalSecondsLeft = free + credits * _creditsToSeconds);
  }

  Future<void> _checkQuotaBeforeCall(String deviceId) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_api/call_quota'),
            headers: {
              'X-API-KEY': AppSecrets.appApiKey,
              'X-Device-Id': deviceId,
            },
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (!(data['can_call'] ?? true)) {
          if (mounted) {
            setState(() {
              _totalSecondsLeft = 0;
              _quotaExhausted = true;
            });
          }
          return;
        }
        _applyQuota(data);
      }
    } catch (e) {
      _log('QUOTA', 'check failed, continuing: $e');
      if (mounted) setState(() => _totalSecondsLeft = 300);
    }
    _connect();
  }

  Future<bool> _reportUsage({bool isFinal = false}) async {
    if (_deviceId.isEmpty) return false;
    final delta = _seconds - _lastSavedSeconds;
    if (delta <= 0) return false;
    try {
      final res = await http
          .post(
            Uri.parse('$_api/call_ended?duration_seconds=$delta'),
            headers: {
              'X-API-KEY': AppSecrets.appApiKey,
              'X-Device-Id': _deviceId,
            },
          )
          .timeout(Duration(seconds: isFinal ? 8 : 5));
      if (res.statusCode != 200) return false;
      _lastSavedSeconds = _seconds;
      try {
        _applyQuota(jsonDecode(res.body) as Map<String, dynamic>);
      } catch (_) {}
      return true;
    } catch (e) {
      _log('QUOTA', 'report failed: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Connect
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _connect() async {
    if (mounted) {
      setState(() {
        _hasError = false;
        _micDenied = false;
        _caption = 'Calling $_aiName…';
      });
    }

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (mounted) {
        setState(() {
          _micDenied = true;
          _hasError = true;
        });
      }
      return;
    }

    // Ask for the camera only after the mic prompt is resolved so the two
    // system dialogs never overlap.
    if (_camera == null && !_cameraDenied) await _initCamera();
    if (_exited || !mounted) return;

    try {
      final res = await http
          .get(
            Uri.parse(
              '$_api/get_token?gender=${widget.voice}&vibe=${widget.vibe}',
            ),
            headers: {
              'X-API-KEY': AppSecrets.appApiKey,
              'X-Device-Id': _deviceId,
            },
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 429) {
        if (mounted) {
          setState(() {
            _quotaExhausted = true;
            _totalSecondsLeft = 0;
          });
        }
        return;
      }
      if (res.statusCode != 200) throw 'API error ${res.statusCode}';
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['token'] as String;
      _applyQuota(data);

      final room = Room(
        roomOptions: const RoomOptions(
          defaultAudioPublishOptions: AudioPublishOptions(name: 'microphone'),
        ),
      );
      _room = room;
      _listener = room.createListener()
        ..on<TrackSubscribedEvent>((e) async {
          if (e.track is RemoteAudioTrack) await e.track.start();
        })
        ..on<DataReceivedEvent>((e) {
          if (!mounted) return;
          final text = utf8.decode(e.data);
          if (text.startsWith('REACTION|')) {
            _emojiTimer?.cancel();
            setState(() => _activeEmoji = text.split('|')[1]);
            _emojiTimer = Timer(const Duration(seconds: 2), () {
              if (mounted) setState(() => _activeEmoji = null);
            });
            return;
          }
          setState(() => _caption = text);
        })
        ..on<RoomDisconnectedEvent>((_) => _safeExit());

      await room.connect(
        'wss://key-5d1ldsh2.livekit.cloud',
        token,
        connectOptions: const ConnectOptions(autoSubscribe: true),
      );
      await Future.delayed(const Duration(milliseconds: 300));
      await room.localParticipant?.setMicrophoneEnabled(true);
      await room.setSpeakerOn(_isSpeakerOn);

      _startTimers();
      _startVisionLoop();
      if (mounted) {
        setState(() {
          _isConnected = true;
          _caption = 'Listening…';
        });
      }
    } catch (e) {
      _log('FATAL', e);
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _startTimers() {
    _statsTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final room = _room;
      if (room == null || !mounted) return;
      final rawAi = room.remoteParticipants.values.firstOrNull?.audioLevel ?? 0;
      // Fast attack, slow release: the glow snaps on with speech and fades out.
      _aiSmooth = rawAi > _aiSmooth
          ? _aiSmooth * .45 + rawAi * .55
          : _aiSmooth * .85 + rawAi * .15;
      _aiLevel.value = _clampD(_aiSmooth * 6, 0, 1);
      _userLevel.value = _clampD(
        (room.localParticipant?.audioLevel ?? 0) * 6,
        0,
        1,
      );
    });

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _seconds++;
        if (_totalSecondsLeft > 0) _totalSecondsLeft--;
      });
      if (_seconds % 30 == 0) _reportUsage();
      if (_totalSecondsLeft <= 0 && !_endingCall) _handleCountdownZero();
    });

    _netTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_room == null || !mounted || !_isConnected) return;
      final next = switch (_room!.localParticipant?.connectionQuality) {
        ConnectionQuality.poor => _NetQuality.poor,
        ConnectionQuality.lost => _NetQuality.lost,
        _ => _NetQuality.good,
      };
      if (next != _net) setState(() => _net = next);
    });
  }

  Future<void> _handleCountdownZero() async {
    if (_exited || _endingCall || _deviceId.isEmpty) return;
    _endingCall = true;
    try {
      final res = await http
          .get(
            Uri.parse('$_api/call_quota'),
            headers: {
              'X-API-KEY': AppSecrets.appApiKey,
              'X-Device-Id': _deviceId,
            },
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final free = _asInt(data['seconds_remaining']);
        final credits = _asInt(data['purchased_credits']);
        final total = free + credits * _creditsToSeconds;
        if (!(data['can_call'] ?? false) || total <= 0) {
          if (mounted) {
            setState(() {
              _quotaExhausted = true;
              _totalSecondsLeft = 0;
            });
          }
          await Future.delayed(const Duration(seconds: 2));
          _safeExit(keepScreen: true);
          return;
        }
        if (mounted) {
          setState(() {
            _totalSecondsLeft = total;
            _endingCall = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _totalSecondsLeft = 60;
        _endingCall = false;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Exit / dispose
  // ══════════════════════════════════════════════════════════════════════════
  void _cancelTimers() {
    _statsTimer?.cancel();
    _durationTimer?.cancel();
    _netTimer?.cancel();
    _visionTimer?.cancel();
    _visionToastTimer?.cancel();
    _emojiTimer?.cancel();
  }

  /// [keepScreen] leaves the "daily limit" screen up after the call is torn down.
  Future<void> _safeExit({bool keepScreen = false}) async {
    if (_exited) return;
    _exited = true;
    _cancelTimers();
    await _tearDownRoom();
    if (!keepScreen && mounted) Navigator.pop(context);
    _backgroundCleanup();
  }

  Future<void> _tearDownRoom() async {
    final room = _room;
    final listener = _listener;
    _room = null;
    _listener = null;
    if (room == null) return;
    try {
      await room.localParticipant?.setMicrophoneEnabled(false);
      await room.localParticipant?.unpublishAllTracks();
      await room.disconnect();
      await listener?.dispose();
      await room.dispose();
    } catch (e) {
      _log('TEARDOWN', e);
    }
  }

  Future<void> _backgroundCleanup() async {
    final delta = _seconds - _lastSavedSeconds;
    final prefs = await SharedPreferences.getInstance();
    if (delta > 0 && _deviceId.isNotEmpty) {
      await prefs.setInt(
        'pending_call_seconds',
        (prefs.getInt('pending_call_seconds') ?? 0) + delta,
      );
      await prefs.setString('pending_call_device_id', _deviceId);
    }
    if (await _reportUsage(isFinal: true)) {
      await prefs.remove('pending_call_seconds');
      await prefs.remove('pending_call_device_id');
    }
    try {
      final userId = prefs.getString('sympy_user_id') ?? '';
      if (userId.isNotEmpty) {
        await http
            .post(
              Uri.parse('$_api/call/summary'),
              headers: {
                'X-API-KEY': AppSecrets.appApiKey,
                'X-User-Id': userId,
              },
            )
            .timeout(const Duration(seconds: 10));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    if (!_exited) {
      _exited = true;
      _cancelTimers();
      _tearDownRoom();
      _backgroundCleanup();
    }
    _pulse.dispose();
    _aiLevel.dispose();
    _userLevel.dispose();
    _camera?.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Formatting
  // ══════════════════════════════════════════════════════════════════════════
  String _clock(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  // ══════════════════════════════════════════════════════════════════════════
  // UI
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_exited) {
          Navigator.pop(context);
        } else {
          _safeExit();
        }
      },
      child: Scaffold(
        backgroundColor: OvieBrand.background,
        body: _hasError
            ? _errorView()
            : _quotaExhausted
            ? _quotaView()
            : _callView(),
      ),
    );
  }

  Widget _callView() {
    final size = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).padding;
    return Stack(
      fit: StackFit.expand,
      children: [
        _avatarLayer(),

        // Soft scrims keep text readable on any avatar image.
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 170,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB3000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 340,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xF2000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),

        // Top bar
        Positioned(
          top: pad.top + 10,
          left: 16,
          right: 16,
          child: _topBar(),
        ),

        // Network banner
        if (_isConnected && _net != _NetQuality.good)
          Positioned(
            top: pad.top + 66,
            left: 24,
            right: 24,
            child: _networkBanner(),
          ),

        // Caption + vision toast + controls
        Positioned(
          left: 16,
          right: 16,
          bottom: pad.bottom + 14,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_visionComment != null) _visionToast(),
              _caption.isEmpty ? const SizedBox.shrink() : _captionBubble(),
              const SizedBox(height: 14),
              _controlDock(),
            ],
          ),
        ),

        // Camera PiP
        if (_cameraEnabled && _cameraReady) _pip(size, pad),

        // Reaction emoji
        if (_activeEmoji != null)
          IgnorePointer(
            child: Center(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(_activeEmoji),
                tween: Tween(begin: .6, end: 1),
                duration: const Duration(milliseconds: 350),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: Text(
                  _activeEmoji!,
                  style: const TextStyle(fontSize: 110),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── AI avatar ─────────────────────────────────────────────────────────────
  Widget _avatarLayer() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _aiLevel]),
      builder: (context, _) {
        final level = _aiLevel.value;
        // A slow breath, plus a lift when the AI speaks.
        final breath = math.sin(_pulse.value * 2 * math.pi) * .004;
        final scale = 1.0 + .012 + breath + level * .018;
        return Stack(
          fit: StackFit.expand,
          children: [
            Transform.scale(
              scale: scale,
              child: Image.asset(
                widget.imagePath,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -.5),
                errorBuilder: (_, __, ___) => const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: OvieBrand.royalGradient,
                  ),
                  child: Center(
                    child: Icon(Icons.person, color: Colors.white38, size: 120),
                  ),
                ),
              ),
            ),
            // Speaking glow rising from the bottom edge of the frame.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, 1.05),
                    radius: 1.05,
                    colors: [
                      OvieBrand.primary.withValues(alpha: .10 + level * .45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Connecting veil
            if (!_isConnected)
              Container(
                color: OvieBrand.background.withValues(alpha: .62),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white.withValues(alpha: .9),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Calling $_aiName…',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _topBar() {
    final low = _totalSecondsLeft <= 30 && _isConnected;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _aiName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                  shadows: [Shadow(blurRadius: 12, color: Colors.black54)],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _LiveDot(active: _isConnected),
                  const SizedBox(width: 7),
                  Text(
                    _isConnected ? 'Live  ${_clock(_seconds)}' : 'Connecting…',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .85),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _Glass(
          color: low ? Colors.redAccent.withValues(alpha: .28) : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 15,
                color: low ? Colors.redAccent.shade100 : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                _clock(_totalSecondsLeft),
                style: TextStyle(
                  color: low ? Colors.redAccent.shade100 : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _networkBanner() {
    final lost = _net == _NetQuality.lost;
    return _Glass(
      color: (lost ? Colors.redAccent : Colors.orangeAccent).withValues(
        alpha: .28,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            lost ? Icons.wifi_off_rounded : Icons.network_wifi_1_bar_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              lost
                  ? 'Connection lost. Trying to reconnect…'
                  : 'Weak connection. Video and voice may lag.',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── Caption ───────────────────────────────────────────────────────────────
  Widget _captionBubble() {
    return _Glass(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          ValueListenableBuilder<double>(
            valueListenable: _aiLevel,
            builder: (_, v, __) => _Bars(
              level: v,
              bars: 5,
              height: 22,
              color: OvieBrand.secondary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                _caption,
                key: ValueKey(_caption),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _visionToast() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Glass(
        color: OvieBrand.secondary.withValues(alpha: .26),
        radius: 18,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            const Icon(Icons.visibility_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$_aiName noticed: $_visionComment',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Controls ──────────────────────────────────────────────────────────────
  Widget _controlDock() {
    return _Glass(
      radius: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: _userLevel,
                builder: (_, v, __) => _Bars(
                  level: _isMuted ? 0 : v,
                  bars: 9,
                  height: 18,
                  color: _isMuted ? Colors.redAccent : Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _isMuted ? 'Muted' : 'You',
                style: TextStyle(
                  color: _isMuted ? Colors.redAccent.shade100 : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RoundButton(
                icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: _isMuted ? 'Unmute' : 'Mute',
                on: _isMuted,
                onTap: () async {
                  setState(() => _isMuted = !_isMuted);
                  await _room?.localParticipant?.setMicrophoneEnabled(
                    !_isMuted,
                  );
                },
              ),
              _RoundButton(
                icon: _cameraEnabled && !_cameraDenied
                    ? Icons.videocam_rounded
                    : Icons.videocam_off_rounded,
                label: _cameraDenied
                    ? 'Allow'
                    : (_cameraEnabled ? 'Camera' : 'Camera off'),
                on: !_cameraEnabled || _cameraDenied,
                onTap: _toggleCamera,
              ),
              // End call
              GestureDetector(
                onTap: _safeExit,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF3B4D),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF3B4D).withValues(alpha: .5),
                        blurRadius: 22,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.call_end_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              _RoundButton(
                icon: Icons.cameraswitch_rounded,
                label: 'Flip',
                on: false,
                enabled: _cameras.length > 1 && _cameraEnabled,
                onTap: _flipCamera,
              ),
              _RoundButton(
                icon: _isSpeakerOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_down_rounded,
                label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                on: _isSpeakerOn,
                onTap: () async {
                  setState(() => _isSpeakerOn = !_isSpeakerOn);
                  await _room?.setSpeakerOn(_isSpeakerOn);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Picture-in-picture ────────────────────────────────────────────────────
  Widget _pip(Size screen, EdgeInsets pad) {
    final size = _pipLarge ? _pipSizeLarge : _pipSize;
    final minY = pad.top + 78;
    final maxY = math.max(minY, screen.height - size.height - 330);
    final maxX = screen.width - size.width - 8;
    final pos = _pipOffset ?? Offset(screen.width - size.width - 16, minY);
    final left = _clampD(pos.dx, 8, maxX);
    final top = _clampD(pos.dy, minY, maxY);
    final cam = _camera;

    return AnimatedPositioned(
      duration: _pipDragging
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      left: left,
      top: top,
      width: size.width,
      height: size.height,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _pipDragging = true),
        onPanUpdate: (d) => setState(() {
          _pipOffset = Offset(
            _clampD(left + d.delta.dx, 8, maxX),
            _clampD(top + d.delta.dy, minY, maxY),
          );
        }),
        onPanEnd: (_) => setState(() {
          // Snap to the nearest side so it never sits in the middle.
          _pipDragging = false;
          final snapLeft = left + size.width / 2 < screen.width / 2;
          _pipOffset = Offset(snapLeft ? 16 : screen.width - size.width - 16, top);
        }),
        onTap: () => setState(() => _pipLarge = !_pipLarge),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: .35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cam != null && cam.value.isInitialized)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: cam.value.previewSize?.height ?? 100,
                      height: cam.value.previewSize?.width ?? 100,
                      child: CameraPreview(cam),
                    ),
                  )
                else
                  const ColoredBox(color: Color(0xFF1A1A2E)),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: _Glass(
                    radius: 10,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Error / limit screens ─────────────────────────────────────────────────
  Widget _errorView() {
    final mic = _micDenied;
    return OvieBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withValues(alpha: .12),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: .35),
                  ),
                ),
                child: Icon(
                  mic ? Icons.mic_off_rounded : Icons.wifi_off_rounded,
                  color: Colors.redAccent,
                  size: 42,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                mic ? 'Microphone access needed' : 'Could not connect',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mic
                    ? 'Allow the microphone in Settings so $_aiName can hear you.'
                    : 'Check your internet connection and try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, height: 1.45),
              ),
              const SizedBox(height: 32),
              OvieGradientButton(
                label: mic ? 'Open settings' : 'Try again',
                icon: mic ? Icons.settings_rounded : Icons.refresh_rounded,
                onPressed: mic ? openAppSettings : _connect,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Back',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quotaView() {
    return OvieBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: OvieBrand.royalGold.withValues(alpha: .12),
                  border: Border.all(
                    color: OvieBrand.royalGold.withValues(alpha: .4),
                  ),
                ),
                child: const Icon(
                  Icons.hourglass_bottom_rounded,
                  color: OvieBrand.royalGold,
                  size: 42,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'You’re out of call time',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your free minutes are used up. Top up to keep talking, or come back tomorrow.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, height: 1.45),
              ),
              const SizedBox(height: 32),
              OvieGradientButton(
                label: 'Get more time',
                icon: Icons.bolt_rounded,
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const UpgradePage()),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Not now',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small building blocks
// ─────────────────────────────────────────────────────────────────────────────

/// Translucent dark surface used over live video. Kept as a flat tint (no
/// backdrop blur) so it stays cheap while two video layers are running.
class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  const _Glass({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.black.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: child,
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool on;
  final bool enabled;
  final VoidCallback onTap;
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.on,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : .35,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on
                    ? Colors.white
                    : Colors.white.withValues(alpha: .14),
              ),
              child: Icon(
                icon,
                size: 22,
                color: on ? OvieBrand.background : Colors.white,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .7),
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  final bool active;
  const _LiveDot({required this.active});
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? Colors.greenAccent : OvieBrand.royalGold;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: .3 + _c.value * .5),
              blurRadius: 4 + _c.value * 6,
            ),
          ],
        ),
      ),
    );
  }
}

/// Symmetric level bars: tall in the middle, short at the edges.
class _Bars extends StatelessWidget {
  final double level; // 0..1
  final int bars;
  final double height;
  final Color color;
  const _Bars({
    required this.level,
    required this.bars,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final mid = (bars - 1) / 2;
    final t = DateTime.now().millisecondsSinceEpoch / 140;
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(bars, (i) {
          final envelope = 1 - ((i - mid).abs() / (mid + 1));
          final wobble = .65 + .35 * math.sin(t + i * 1.7);
          final h = _clampD(
            4 + (height - 4) * level * envelope * wobble,
            4,
            height,
          );
          return AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 3.5,
            height: h,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .55 + level * .45),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
