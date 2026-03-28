import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:proximity_sensor/proximity_sensor.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'secrets.dart';
import 'Upgradepage.dart';

class CallScreen extends StatefulWidget {
  final String voice;
  final String vibe;
  final String imagePath;
  const CallScreen({
    super.key,
    required this.voice,
    required this.vibe,
    required this.imagePath,
  });
  @override
  State<CallScreen> createState() => _CallScreenState();
}

// Network quality levels — maps LiveKit ConnectionQuality to our UI states
enum _NetQuality { good, poor, lost }

class _CallScreenState extends State<CallScreen> {
  // ==================== LIVEKIT / AUDIO STATE ====================
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  double _userLevel = 0;
  double _aiLevel = 0;
  Timer? _statsTimer;
  Timer? _durationTimer;
  int _seconds = 0;
  String _lastTranscript = "Connecting to sympy...";
  bool _exited = false;
  String? _activeEmoji;
  bool _hasError = false;
  bool _micDenied = false;

  String _deviceId = "";

  // ── Unified credit countdown ──────────────────────────────────
  int _totalSecondsLeft = 0;
  int _totalSecondsAtStart = 0;
  int _purchasedCredits = 0;
  bool _quotaExhausted = false;
  bool _endingCall = false;
  int _lastSavedSeconds = 0;

  late List<String> _displayTexts;
  int _textIndex = 0;
  Timer? _textFadeTimer;

  static const int _secondsPerCredit = 12;
  int _creditsToSeconds(int credits) => credits * _secondsPerCredit;

  String _formatTime(int secs) {
    if (secs <= 0) return "0s";
    if (secs < 60) return "${secs}s";
    final m = secs ~/ 60;
    final s = secs % 60;
    return s == 0 ? "${m}m" : "${m}m ${s}s";
  }

  // ── Network quality ───────────────────────────────────────────
  // Polled from LiveKit's ConnectionQuality every 2 s.
  // Only shown after connection is established to avoid false positives
  // during the connect phase.
  _NetQuality _netQuality = _NetQuality.good;
  Timer? _netQualityTimer;

  void _startNetworkQualityPolling() {
    _netQualityTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_room == null || !mounted || !_isConnected) return;
      final q = _room!.localParticipant?.connectionQuality;
      _NetQuality newQuality;
      switch (q) {
        case ConnectionQuality.poor:
          newQuality = _NetQuality.poor;
          break;
        case ConnectionQuality.lost:
          newQuality = _NetQuality.lost;
          break;
        default:
          newQuality = _NetQuality.good;
      }
      if (newQuality != _netQuality) {
        setState(() => _netQuality = newQuality);
      }
    });
  }

  // ── Proximity sensor (screen dim on ear) ─────────────────────
  // When the phone is held to the ear the proximity sensor fires near=true.
  // We cover the screen with a fully opaque black overlay and disable
  // touch input — exactly like a normal phone call does.
  // When the hand moves away it restores instantly.
  bool _screenDimmed = false;
  StreamSubscription<int>? _proximitySub;

  void _startProximitySensor() async {
    try {
      // setProximityScreenOff(true) — Android only, safe to call on iOS
      // (no-op there). This tells the OS to turn off the screen when
      // the sensor fires, exactly like a native phone call does.
      // Requires WAKE_LOCK permission in AndroidManifest.xml.
      await ProximitySensor.setProximityScreenOff(true).onError((e, _) {
        _log("PROXIMITY", "setProximityScreenOff error: $e");
        return null;
      });

      // ProximitySensor.events emits int: > 0 = near, 0 = far
      _proximitySub = ProximitySensor.events.listen((int event) {
        if (!mounted) return;
        final bool near = event > 0;
        if (near != _screenDimmed) {
          setState(() => _screenDimmed = near);
          // Immersive mode hides status/nav bars while near for a
          // cleaner black screen. Restore on move-away.
          if (near) {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          } else {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          }
        }
      }, onError: (e) {
        _log("PROXIMITY", "Stream error: $e");
      });
    } catch (e) {
      _log("PROXIMITY", "Not available on this device: $e");
    }
  }

  void _stopProximitySensor() async {
    try {
      await ProximitySensor.setProximityScreenOff(false).onError((e, _) => null);
    } catch (_) {}
    _proximitySub?.cancel();
    _proximitySub = null;
    if (mounted) setState(() => _screenDimmed = false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void initState() {
    super.initState();
    final aiName = widget.voice == "male" ? "Buddy" : "Missy";
    _displayTexts = [
      aiName,
      "Cooking up some major vibes... 🍳",
      "Checking the street for update... 🤫",
      "Abeg hold on, I dey find words... 🧐",
      "Vibe check in progress... 🔋",
      "Sharpening my tongue... 🔪",
    ];
    _startTextRotation();
    _loadDeviceIdThenConnect();
  }

  void _startTextRotation() {
    _textFadeTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() => _textIndex = (_textIndex + 1) % _displayTexts.length);
      }
    });
  }

  void _log(String tag, dynamic message) =>
      debugPrint("[CallScreen | $tag] $message");

  // ==================== PERMISSIONS ====================
  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      _log("MIC", "Permission granted");
      return true;
    }
    _log("MIC", "Permission denied: $status");
    if (mounted) setState(() => _micDenied = true);
    return false;
  }

  // ==================== DEVICE ID + QUOTA ====================
  Future<void> _loadDeviceIdThenConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
    String stored;
    if (firebaseUid != null) {
      stored = "user_$firebaseUid";
      await prefs.setString("sympy_user_id", stored);
    } else {
      String? existing = prefs.getString("sympy_user_id");
      if (existing == null) {
        final rand = DateTime.now().millisecondsSinceEpoch.toString();
        existing = "user_${rand.substring(rand.length - 10)}";
        await prefs.setString("sympy_user_id", existing);
      }
      stored = existing;
    }
    if (mounted) setState(() => _deviceId = stored);
    await _flushPendingSeconds(prefs, stored);
    await _checkQuotaBeforeCall(stored);
  }

  Future<void> _flushPendingSeconds(
      SharedPreferences prefs, String deviceId) async {
    final pending = prefs.getInt("pending_call_seconds") ?? 0;
    final pendingDevice = prefs.getString("pending_call_device_id") ?? "";
    if (pending <= 0 || pendingDevice.isEmpty) return;
    try {
      final res = await http.post(
        Uri.parse(
            "https://web-production-6c359.up.railway.app/call_ended?duration_seconds=$pending"),
        headers: {
          "X-API-KEY": AppSecrets.appApiKey,
          "X-Device-Id": pendingDevice,
        },
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        await prefs.remove("pending_call_seconds");
        await prefs.remove("pending_call_device_id");
        _log("QUOTA", "Flushed $pending pending seconds from last crash");
      }
    } catch (e) {
      _log("QUOTA", "Could not flush pending seconds: $e");
    }
  }

  void _applyQuotaData(Map<String, dynamic> data) {
    final int free = data["seconds_remaining"] ?? 0;
    final int credits = data["purchased_credits"] ?? 0;
    final int total = free + _creditsToSeconds(credits);
    setState(() {
      _purchasedCredits = credits;
      _totalSecondsLeft = total;
      if (_totalSecondsAtStart == 0) _totalSecondsAtStart = total;
    });
  }

  Future<void> _checkQuotaBeforeCall(String deviceId) async {
    try {
      final res = await http.get(
        Uri.parse("https://web-production-6c359.up.railway.app/call_quota"),
        headers: {
          "X-API-KEY": AppSecrets.appApiKey,
          "X-Device-Id": deviceId,
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final bool canCall = data["can_call"] ?? true;
        if (!canCall) {
          if (mounted) {
            setState(() {
              _totalSecondsLeft = 0;
              _purchasedCredits = 0;
              _quotaExhausted = true;
              _lastTranscript =
                  "You've used your free minutes. Top up to keep calling! 🎉";
            });
          }
          return;
        }
        if (mounted) _applyQuotaData(data);
      }
    } catch (e) {
      _log("QUOTA", "Quota check failed: $e — proceeding fail-open");
      if (mounted) {
        setState(() {
          _totalSecondsLeft = 300;
          _totalSecondsAtStart = 300;
        });
      }
    }
    _connect();
  }

  Future<bool> _reportUsage({bool isFinal = false}) async {
    if (_deviceId.isEmpty) return false;
    final int delta = _seconds - _lastSavedSeconds;
    if (delta <= 0) return false;
    try {
      final res = await http.post(
        Uri.parse(
            "https://web-production-6c359.up.railway.app/call_ended?duration_seconds=$delta"),
        headers: {
          "X-API-KEY": AppSecrets.appApiKey,
          "X-Device-Id": _deviceId,
        },
      ).timeout(Duration(seconds: isFinal ? 8 : 5));

      if (res.statusCode == 200) {
        _lastSavedSeconds = _seconds;
        try {
          final data = jsonDecode(res.body);
          if (mounted) {
            final int free = data["seconds_remaining"] ?? 0;
            final int credits = data["purchased_credits"] ?? 0;
            final int serverTotal = free + _creditsToSeconds(credits);
            setState(() {
              _purchasedCredits = credits;
              _totalSecondsLeft = serverTotal;
            });
            _log("QUOTA",
                "Synced — ${_formatTime(serverTotal)} left (${free}s free + ${credits}cr)");
          }
        } catch (_) {}
        return true;
      }
      return false;
    } catch (e) {
      _log("QUOTA", "Failed to report usage: $e");
      return false;
    }
  }

  Future<bool> _reportCallEnded() => _reportUsage(isFinal: true);

  // ==================== CONNECT ====================
  Future<void> _connect() async {
    if (mounted) {
      setState(() {
        _hasError = false;
        _micDenied = false;
        _lastTranscript = "Connecting to sympy...";
      });
    }

    final bool micGranted = await _requestMicPermission();
    if (!micGranted) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final url =
          "https://web-production-6c359.up.railway.app/get_token?gender=${widget.voice}&vibe=${widget.vibe}";
      final res = await http.get(
        Uri.parse(url),
        headers: {
          "X-API-KEY": AppSecrets.appApiKey,
          "X-Device-Id": _deviceId,
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 429) {
        if (mounted) {
          setState(() {
            _quotaExhausted = true;
            _totalSecondsLeft = 0;
            _purchasedCredits = 0;
            _lastTranscript =
                "You've used your free minutes. Top up to keep calling! 🎉";
          });
        }
        return;
      }

      if (res.statusCode != 200) throw "API Error: ${res.statusCode}";
      final data = jsonDecode(res.body);
      final String token = data["token"];

      if (mounted) _applyQuotaData(data);

      _room = Room(
        roomOptions: const RoomOptions(
          defaultAudioPublishOptions: AudioPublishOptions(
            name: 'microphone',
          ),
        ),
      );

      _listener = _room!.createListener();
      _listener!
        ..on<TrackSubscribedEvent>((event) async {
          if (event.track is RemoteAudioTrack) {
            await event.track.start();
          }
        })
        ..on<DataReceivedEvent>((event) {
          final text = utf8.decode(event.data);
          if (!mounted) return;
          if (text.startsWith("REACTION|")) {
            setState(() => _activeEmoji = text.split("|")[1]);
            Timer(const Duration(seconds: 2), () {
              if (mounted) setState(() => _activeEmoji = null);
            });
            return;
          }
          setState(() => _lastTranscript = text);
        })
        ..on<RoomDisconnectedEvent>((event) => _safeExit());

      await _room!.connect(
        "wss://key-5d1ldsh2.livekit.cloud",
        token,
        connectOptions: const ConnectOptions(autoSubscribe: true),
      );

      await Future.delayed(const Duration(milliseconds: 300));
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      await _room!.setSpeakerOn(_isSpeakerOn);

      _startTimers();
      _startNetworkQualityPolling();
      _startProximitySensor();

      if (mounted) {
        setState(() {
          _isConnected = true;
          _lastTranscript = "Listening...";
        });
      }

      _log("MIC",
          "Mic enabled — audioLevel=${_room!.localParticipant?.audioLevel}");
    } catch (e) {
      _log("FATAL", e.toString());
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _startTimers() {
    _statsTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_room == null || !mounted) return;
      final newUserLevel = _room!.localParticipant?.audioLevel ?? 0;
      final newAiLevel =
          _room!.remoteParticipants.values.firstOrNull?.audioLevel ?? 0;
      if ((newUserLevel - _userLevel).abs() > 0.01 ||
          (newAiLevel - _aiLevel).abs() > 0.01) {
        setState(() {
          _userLevel = newUserLevel;
          _aiLevel = newAiLevel;
        });
      }
    });

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _seconds++;
        if (_totalSecondsLeft > 0) _totalSecondsLeft--;
      });
      if (_seconds % 30 == 0) _reportUsage();
      if (_totalSecondsLeft <= 0 && !_endingCall) {
        _log("QUOTA", "Countdown at zero — verifying with backend");
        _handleCountdownZero();
      }
    });
  }

  Future<void> _handleCountdownZero() async {
    if (_exited || _endingCall || _deviceId.isEmpty) return;
    _endingCall = true;
    try {
      final res = await http.get(
        Uri.parse("https://web-production-6c359.up.railway.app/call_quota"),
        headers: {
          "X-API-KEY": AppSecrets.appApiKey,
          "X-Device-Id": _deviceId,
        },
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final bool canCall = data["can_call"] ?? false;
        final int free = data["seconds_remaining"] ?? 0;
        final int credits = data["purchased_credits"] ?? 0;
        final int serverTotal = free + _creditsToSeconds(credits);
        if (!canCall || serverTotal <= 0) {
          _log("QUOTA", "Confirmed zero — ending call");
          if (mounted) {
            setState(() {
              _quotaExhausted = true;
              _totalSecondsLeft = 0;
              _purchasedCredits = 0;
            });
          }
          await Future.delayed(const Duration(seconds: 2));
          _safeExit();
        } else {
          if (mounted) {
            setState(() {
              _purchasedCredits = credits;
              _totalSecondsLeft = serverTotal;
              _endingCall = false;
            });
          }
        }
      } else {
        if (mounted) setState(() { _totalSecondsLeft = 60; _endingCall = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _totalSecondsLeft = 60; _endingCall = false; });
    }
  }

  Future<void> _safeExit() async {
    if (_exited) return;
    _exited = true;
    _statsTimer?.cancel();
    _durationTimer?.cancel();
    _textFadeTimer?.cancel();
    _netQualityTimer?.cancel();
    _stopProximitySensor();

    try {
      if (_room != null) {
        await _room!.localParticipant?.setMicrophoneEnabled(false);
        await _room!.localParticipant?.unpublishAllTracks();
        await _room!.disconnect();
        await _listener?.dispose();
        await _room!.dispose();
        _room = null;
      }
    } catch (e) {
      _log("EXIT_ERROR", e);
    }

    if (mounted) Navigator.pop(context);
    _doBackgroundCleanup();
  }

  void _doBackgroundCleanup() async {
    final int delta = _seconds - _lastSavedSeconds;
    final prefs = await SharedPreferences.getInstance();
    if (delta > 0 && _deviceId.isNotEmpty) {
      final int pending =
          (prefs.getInt("pending_call_seconds") ?? 0) + delta;
      await prefs.setInt("pending_call_seconds", pending);
      await prefs.setString("pending_call_device_id", _deviceId);
    }
    final reported = await _reportCallEnded();
    if (reported) {
      await prefs.remove("pending_call_seconds");
      await prefs.remove("pending_call_device_id");
    }
    try {
      final userId = prefs.getString("sympy_user_id") ?? "";
      if (userId.isNotEmpty) {
        await http.post(
          Uri.parse(
              "https://web-production-6c359.up.railway.app/call/summary"),
          headers: {
            "X-API-KEY": AppSecrets.appApiKey,
            "X-User-Id": userId,
          },
        ).timeout(const Duration(seconds: 10));
      }
    } catch (_) {}
  }

  String _elapsedTime() =>
      "${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}";

  @override
  void dispose() {
    if (!_exited) {
      _exited = true;
      _statsTimer?.cancel();
      _durationTimer?.cancel();
      _textFadeTimer?.cancel();
      _netQualityTimer?.cancel();
      _stopProximitySensor();
      _tearDownRoom();
      _doBackgroundCleanup();
    }
    super.dispose();
  }

  void _tearDownRoom() {
    final room = _room;
    final listener = _listener;
    _room = null;
    _listener = null;
    if (room == null) return;
    Future(() async {
      try {
        await room.localParticipant?.setMicrophoneEnabled(false);
        await room.localParticipant?.unpublishAllTracks();
        await room.disconnect();
        await listener?.dispose();
        await room.dispose();
        _log("TEARDOWN", "Room torn down from dispose()");
      } catch (e) {
        _log("TEARDOWN", "Room teardown error: $e");
      }
    });
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _safeExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF060714),
        body: SafeArea(
          child: Stack(
            children: [
              // Main content
              _hasError ? _buildErrorView() : _buildCallView(),

              // ── Proximity screen dimmer ────────────────────────
              // Full-screen black overlay when phone is near ear.
              // AbsorbPointer prevents any accidental touch input
              // while the screen is against the user's face.
              if (_screenDimmed)
                Positioned.fill(
                  child: AbsorbPointer(
                    absorbing: true,
                    child: Container(color: Colors.black),
                  ),
                ),

              // ── Network quality overlay + banner ──────────────
              // A semi-transparent red tint covers the whole screen
              // when network is poor or lost — like WhatsApp.
              // The banner at the top gives the text detail.
              if (_isConnected && _netQuality != _NetQuality.good)
                _buildNetworkOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Network quality overlay — full screen tint + top banner ────
  // Poor network  → amber/orange tint + banner
  // Lost/no signal → red tint + banner
  // Matches WhatsApp behaviour: whole screen changes colour so the
  // user can't miss it even if they're not looking at the top bar.
  Widget _buildNetworkOverlay() {
    final bool isLost = _netQuality == _NetQuality.lost;

    // Tint colour — subtle enough not to block the UI but obvious enough
    // to notice immediately
    final Color tint = isLost
        ? Colors.red.withOpacity(0.18)
        : Colors.orange.withOpacity(0.12);

    // Banner background — solid so the text is always readable
    final Color bannerBg = isLost
        ? const Color(0xFFB71C1C)
        : const Color(0xFFE65100);

    final String message = isLost
        ? "No connection — trying to reconnect..."
        : "Poor connection — call quality may be affected";

    final IconData icon = isLost
        ? Icons.signal_wifi_off_rounded
        : Icons.signal_wifi_bad_rounded;

    return Stack(
      children: [
        // Full-screen colour tint — IgnorePointer so touches still work
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              color: tint,
            ),
          ),
        ),
        // Top banner with message
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            color: bannerBg,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _PulsingDot(
                  color: isLost
                      ? Colors.red.shade200
                      : Colors.orange.shade200),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF060714), Color(0xFF0d0d2b), Color(0xFF060714)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withOpacity(0.1),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Icon(
                _micDenied ? Icons.mic_off : Icons.error_outline,
                color: Colors.redAccent,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _micDenied ? "Microphone Access Denied" : "Connection Failed",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _micDenied
                    ? "Sympy needs your microphone to hear you. Please allow mic access in your phone's Settings, then try again."
                    : "Something went wrong. Please try again.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                    height: 1.5),
              ),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: () {
                if (_micDenied) {
                  openAppSettings();
                } else {
                  _connect();
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                      colors: [Colors.blueAccent, Colors.purpleAccent]),
                ),
                child: Text(
                  _micDenied ? "Open Settings" : "Try Again",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Unified credit countdown widget ───────────────────────────
  Widget _buildCreditCountdown() {
    if (_quotaExhausted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.redAccent, size: 13),
            SizedBox(width: 5),
            Text("No credits — ending call",
                style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final bool isRed = _totalSecondsLeft <= 30;
    final bool isAmber = !isRed && _totalSecondsLeft <= 120;
    final Color color = isRed
        ? Colors.redAccent
        : isAmber
            ? Colors.amber
            : Colors.blueAccent;
    final double progress = _totalSecondsAtStart > 0
        ? (_totalSecondsLeft / _totalSecondsAtStart).clamp(0.0, 1.0)
        : 1.0;
    final String timeLabel = _formatTime(_totalSecondsLeft);
    final String creditLabel =
        _purchasedCredits > 0 ? " · $_purchasedCredits cr" : "";

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isRed ? Icons.warning_amber_rounded : Icons.bolt_rounded,
                color: color,
                size: 13,
              ),
              const SizedBox(width: 5),
              Text(
                "$timeLabel left$creditLabel",
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight:
                      isRed || isAmber ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 180,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCallView() {
    final aiName = widget.voice == "male" ? "Buddy" : "Missy";

    // Quota exhausted before connecting
    if (_quotaExhausted && !_isConnected) {
      return Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF060714), Color(0xFF0d0d2b), Color(0xFF060714)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
              top: -60, left: -60,
              child: Container(
                  width: 260, height: 260,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent.withOpacity(0.05)))),
          Positioned(
              bottom: 120, right: -40,
              child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.purpleAccent.withOpacity(0.05)))),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.purpleAccent.withOpacity(0.25),
                            blurRadius: 40,
                            spreadRadius: 4)
                      ],
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        color: Colors.purpleAccent, size: 48),
                  ),
                  const SizedBox(height: 28),
                  const Text("No Credits Left!",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(
                      "Top up credits to keep calling — every pack gives you real call time! 🎉",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 15,
                          height: 1.5),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const UpgradePage()));
                    },
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                            colors: [Color(0xFF7b2ff7), Color(0xFF4776E6)]),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.purpleAccent.withOpacity(0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8))
                        ],
                      ),
                      child: const Center(
                        child: Text("⚡ Top Up Credits",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text("Maybe later",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white.withOpacity(0.3))),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF060714), Color(0xFF0d0d2b), Color(0xFF060714)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned(
            top: -60, left: -60,
            child: Container(
                width: 260, height: 260,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent.withOpacity(0.07)))),
        Positioned(
            bottom: 120, right: -40,
            child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.purpleAccent.withOpacity(0.06)))),

        Column(
          children: [
            // Extra top padding when network banner is visible so content
            // doesn't slide under it
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: (_isConnected && _netQuality != _NetQuality.good) ? 42 : 16,
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: (_isConnected ? Colors.green : Colors.blueAccent)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: (_isConnected
                                  ? Colors.green
                                  : Colors.blueAccent)
                              .withOpacity(0.4)),
                    ),
                    child: Row(children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: _isConnected
                                  ? Colors.green
                                  : Colors.blueAccent,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(
                        _isConnected ? "Live" : "Connecting",
                        style: TextStyle(
                            color: _isConnected
                                ? Colors.green
                                : Colors.blueAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ]),
                  ),
                  const SizedBox(),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text(
              _isConnected ? _elapsedTime() : "Connecting...",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  fontFamily: 'monospace',
                  letterSpacing: 3),
            ),
            const SizedBox(height: 6),

            _buildCreditCountdown(),

            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.5),
                      blurRadius: 40,
                      spreadRadius: 6),
                  BoxShadow(
                      color: Colors.purpleAccent.withOpacity(0.3),
                      blurRadius: 60,
                      spreadRadius: 12),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [Colors.blueAccent, Colors.purpleAccent]),
                ),
                child: ClipOval(
                  child: Image.asset(
                    widget.imagePath,
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 110,
                      height: 110,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                            colors: [Colors.blueAccent, Colors.purpleAccent]),
                      ),
                      child: const Icon(Icons.person,
                          color: Colors.white, size: 50),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(aiName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: Text(
                _displayTexts[_textIndex],
                key: ValueKey<int>(_textIndex),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 13),
              ),
            ),

            const SizedBox(height: 20),

            WaveWidget(level: _aiLevel, color: Colors.blueAccent),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Text(
                  _lastTranscript,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      height: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 16),

            WaveWidget(
                level: _isMuted ? 0 : _userLevel,
                color: _isMuted ? Colors.redAccent : Colors.greenAccent),
            const SizedBox(height: 4),
            Text(
              _isMuted ? "🔇 MIC MUTED" : "🎙 YOU",
              style: TextStyle(
                  color: _isMuted
                      ? Colors.redAccent.withOpacity(0.8)
                      : Colors.greenAccent.withOpacity(0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2),
            ),

            const Spacer(),

            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Text("Vibe: ${widget.vibe}",
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.3), fontSize: 12)),
            ),

            const SizedBox(height: 24),
            Container(
                height: 1,
                color: Colors.white.withOpacity(0.06),
                margin: const EdgeInsets.symmetric(horizontal: 24)),
            const SizedBox(height: 28),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _callButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: _isMuted ? "Unmute" : "Mute",
                    active: !_isMuted,
                    onTap: () async {
                      setState(() => _isMuted = !_isMuted);
                      await _room!.localParticipant
                          ?.setMicrophoneEnabled(!_isMuted);
                    },
                  ),
                  GestureDetector(
                    onTap: _safeExit,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.redAccent,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.redAccent.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 2)
                        ],
                      ),
                      child: const Icon(Icons.call_end,
                          color: Colors.white, size: 30),
                    ),
                  ),
                  _callButton(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                    label: _isSpeakerOn ? "Speaker" : "Earpiece",
                    active: _isSpeakerOn,
                    onTap: () async {
                      setState(() => _isSpeakerOn = !_isSpeakerOn);
                      await _room!.setSpeakerOn(_isSpeakerOn);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),
          ],
        ),

        if (_activeEmoji != null)
          Center(
              child: Text(_activeEmoji!,
                  style: const TextStyle(fontSize: 120))),
      ],
    );
  }

  Widget _callButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? Colors.white.withOpacity(0.12)
                  : Colors.white.withOpacity(0.05),
              border: Border.all(
                  color: active
                      ? Colors.white.withOpacity(0.25)
                      : Colors.white.withOpacity(0.08)),
            ),
            child: Icon(icon,
                color: active ? Colors.white : Colors.white38, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Pulsing dot shown in network banner ───────────────────────────
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
        ),
      ),
    );
  }
}

class WaveWidget extends StatelessWidget {
  final double level;
  final Color color;
  const WaveWidget({super.key, required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(20, (i) {
        final center = 9.5;
        final base = 6.0;
        final peak =
            base + (level * 80 * (1 - ((i - center).abs() / center)));
        final h = peak.clamp(base, 80.0);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 3,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.9),
                color.withOpacity(0.4),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        );
      }),
    );
  }
}





