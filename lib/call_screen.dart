import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'secrets.dart';

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
  bool _isReconnecting = false;

  String _deviceId = "";
  int _secondsRemaining = 0; // always fetched from server — never assume 300
  int _lastSavedSeconds = 0; // tracks what we last reported to backend
  bool _quotaExhausted = false;

  late List<String> _displayTexts;
  int _textIndex = 0;
  Timer? _textFadeTimer;

  @override
  void initState() {
    super.initState();
    // ✅ AI name from voice selection
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
    _textFadeTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _textIndex = (_textIndex + 1) % _displayTexts.length;
        });
      }
    });
  }

  void _log(String tag, dynamic message) {
    debugPrint("[CallScreen | $tag] $message");
  }

  // ==================== DEVICE ID + QUOTA ====================
  Future<void> _loadDeviceIdThenConnect() async {
    // Step 1 — get stable device ID
    final prefs = await SharedPreferences.getInstance();
    String? stored = prefs.getString("sympy_user_id");
    if (stored == null) {
      final rand = DateTime.now().millisecondsSinceEpoch.toString();
      stored = "user_${rand.substring(rand.length - 10)}";
      await prefs.setString("sympy_user_id", stored);
    }
    if (mounted) setState(() => _deviceId = stored!);

    // Step 2 — flush any seconds from last call that failed to report
    await _flushPendingSeconds(prefs, stored!);

    // Step 3 — check how many seconds are left TODAY before connecting
    await _checkQuotaBeforeCall(stored!);
  }

  Future<void> _flushPendingSeconds(SharedPreferences prefs, String deviceId) async {
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
        // Clear pending after successful flush
        await prefs.remove("pending_call_seconds");
        await prefs.remove("pending_call_device_id");
        _log("QUOTA", "Flushed $pending pending seconds from last session");
      }
    } catch (e) {
      _log("QUOTA", "Could not flush pending seconds: $e");
    }
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
        final int remaining = data["seconds_remaining"] ?? 0;
        final bool canCall = data["can_call"] ?? false;

        if (!canCall || remaining <= 0) {
          // No time left — show limit screen, don't connect
          if (mounted) {
            setState(() {
              _secondsRemaining = 0;
              _quotaExhausted = true;
              _lastTranscript = "You've used your 5 minutes for today. Come back tomorrow! 🕐";
            });
          }
          return;
        }

        // Has time left — set the real remaining seconds then connect
        if (mounted) setState(() => _secondsRemaining = remaining);
      }
    } catch (e) {
      _log("QUOTA", "Could not check quota: $e — proceeding with default");
      if (mounted) setState(() => _secondsRemaining = 300);
    }

    _connect();
  }

  /// Reports seconds used since the last save — sends delta, not total.
  /// Called every 30s during the call AND when the call ends.
  Future<void> _reportUsage({bool isFinal = false}) async {
    if (_deviceId.isEmpty) return;
    final delta = _seconds - _lastSavedSeconds;
    if (delta <= 0) return;

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
        _lastSavedSeconds = _seconds; // mark saved
        _log("QUOTA", "Saved $delta seconds (total: $_seconds)");
      }
    } catch (e) {
        _log("QUOTA", "Failed to save usage: $e");
    }
  }

  // Keep old name as alias so dispose() still works
  Future<void> _reportCallEnded() => _reportUsage(isFinal: true);

  Future<void> _connect() async {
    setState(() {
      _hasError = false;
      _lastTranscript = "Connecting to sympy...";
    });

    try {
      // Small delay to let previous audio sessions fully die
      await Future.delayed(const Duration(milliseconds: 800));

            final url =
          "https://web-production-6c359.up.railway.app/get_token?gender=${widget.voice}&vibe=${widget.vibe}";
      final res = await http
          .get(Uri.parse(url), headers: {
            "X-API-KEY": AppSecrets.appApiKey,
            "X-Device-Id": _deviceId, // ✅ Bug 1 fixed: send device ID
          })
          .timeout(const Duration(seconds: 15));

      // Daily limit hit
      if (res.statusCode == 429) {
        if (mounted) setState(() {
          _quotaExhausted = true;
          _secondsRemaining = 0;
          _lastTranscript = "You've used your 5 minutes for today. Come back tomorrow! 🕐";
        });
        return;
      }

      if (res.statusCode != 200) throw "API Error: ${res.statusCode}";
      final data = jsonDecode(res.body);
      final String token = data["token"];

      // ✅ Bug 2 fixed: always sync remaining seconds from server
      if (data["seconds_remaining"] != null && mounted) {
        setState(() => _secondsRemaining = (data["seconds_remaining"] as int).clamp(0, 300));
      }

      // Initialize Room
      _room = Room();
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
            Timer(const Duration(seconds: 2),
                () => setState(() => _activeEmoji = null));
            return;
          }
          setState(() => _lastTranscript = text);
        })
        ..on<RoomDisconnectedEvent>((event) => _safeExit());

      // Connect to LiveKit
      await _room!.connect("wss://key-5d1ldsh2.livekit.cloud", token);

      // Setup Audio for Android
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      await _room!.setSpeakerOn(_isSpeakerOn);

      _startTimers();
      if (mounted) {
        setState(() {
          _isConnected = true;
          _lastTranscript =
              "Listening...";
        });
      }
    } catch (e) {
      _log("FATAL", e.toString());
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _startTimers() {
    _statsTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_room == null || !mounted) return;
      setState(() {
        _userLevel = _room!.localParticipant?.audioLevel ?? 0;
        final remote = _room!.remoteParticipants.values.firstOrNull;
        _aiLevel = remote?.audioLevel ?? 0;
      });
    });
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _seconds++;
        _secondsRemaining = (_secondsRemaining - 1).clamp(0, 300);
      });

      // Save usage to backend every 30 seconds so crashes don't lose time
      if (_seconds % 30 == 0) {
        _reportUsage();
      }

      // Auto-end call when daily limit reached
      if (_secondsRemaining <= 0) {
        _log("QUOTA", "Daily limit reached — ending call");
        _safeExit();
      }
    });
  }

  Future<void> _safeExit() async {
    if (_exited) return;
    _exited = true;

    _statsTimer?.cancel();
    _durationTimer?.cancel();
    _textFadeTimer?.cancel();

    // ✅ Save unsaved seconds to SharedPreferences FIRST (survives widget death)
    final delta = _seconds - _lastSavedSeconds;
    if (delta > 0 && _deviceId.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final pending = (prefs.getInt("pending_call_seconds") ?? 0) + delta;
      await prefs.setInt("pending_call_seconds", pending);
      await prefs.setString("pending_call_device_id", _deviceId);
    }

    // Then report to backend — widget still alive at this point
    await _reportCallEnded();

    // ✅ Generate call summary after every call
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString("sympy_user_id") ?? "";
      if (userId.isNotEmpty) {
        await http.post(
          Uri.parse("https://web-production-6c359.up.railway.app/call/summary"),
          headers: {
            "X-API-KEY": AppSecrets.appApiKey,
            "X-User-Id": userId,
          },
        ).timeout(const Duration(seconds: 10));
      }
    } catch (_) {}

    try {
      _log("EXIT", "Full Cleanup");

      if (_room != null) {
        await _room!.localParticipant?.unpublishAllTracks();
        await _room!.disconnect();
        await _listener?.dispose();
        await _room!.dispose();
      }
      _room = null;
    } catch (e) {
      _log("EXIT_ERROR", e);
    }

    if (mounted) Navigator.pop(context);
  }

  String _time() =>
      "${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}";

  @override
  void dispose() {
    // _safeExit is already awaited before Navigator.pop so this is just a safety net
    if (!_exited) {
      _exited = true;
      _statsTimer?.cancel();
      _durationTimer?.cancel();
      _textFadeTimer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: _hasError ? _buildErrorView() : _buildCallView()),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 80),
          const SizedBox(height: 20),
          const Text("Connection Failed",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          ElevatedButton(onPressed: _connect, child: const Text("Try Again")),
        ],
      ),
    );
  }

  Widget _buildCallView() {
    return Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 20),
            Text(_isConnected ? _time() : "Connecting...",
                style: const TextStyle(
                    color: Colors.white54, fontFamily: 'monospace')),

            // ✅ Show remaining call time
            Text(
              _quotaExhausted
                  ? "⏰ Daily limit reached"
                  : "⏱ ${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')} remaining today",
              style: TextStyle(
                color: _secondsRemaining <= 30 ? Colors.redAccent : Colors.white54,
                fontSize: 12,
                fontWeight: _secondsRemaining <= 30 ? FontWeight.bold : FontWeight.normal,
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15)),
                child: Text(_lastTranscript,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontStyle: FontStyle.italic)),
              ),
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.5), width: 2)),
              child: ClipOval(
                  child: Image.asset(widget.imagePath,
                      width: 100, height: 100, fit: BoxFit.cover)),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              child: Text(_displayTexts[_textIndex],
                  key: ValueKey<int>(_textIndex),
                  style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            Text("Vibe: ${widget.vibe}",
                style: const TextStyle(color: Colors.white24, fontSize: 14)),
            const SizedBox(height: 30),
            WaveWidget(level: _aiLevel, color: Colors.blueAccent),
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Icon(Icons.compare_arrows, color: Colors.white10)),
            WaveWidget(level: _isMuted ? 0 : _userLevel, color: Colors.greenAccent),
            const SizedBox(height: 20),
            Text(_isMuted ? "MIC MUTED" : "YOU ARE SPEAKING",
                style: TextStyle(
                    color: _isMuted ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _circle(Icons.mic, !_isMuted, () async {
                    setState(() => _isMuted = !_isMuted);
                    await _room!.localParticipant?.setMicrophoneEnabled(!_isMuted);
                  }),
                  _circle(Icons.call_end, false, _safeExit, red: true),
                  _circle(Icons.volume_up, _isSpeakerOn, () async {
                    setState(() => _isSpeakerOn = !_isSpeakerOn);
                    await _room!.setSpeakerOn(_isSpeakerOn);
                  }),
                ],
              ),
            ),
          ],
        ),
        if (_activeEmoji != null)
          Center(child: Text(_activeEmoji!, style: const TextStyle(fontSize: 120))),
      ],
    );
  }

  Widget _circle(IconData icon, bool active, VoidCallback onTap, {bool red = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: red
                ? Colors.red
                : (active ? Colors.white12 : Colors.red.withOpacity(0.2))),
        child: Icon(icon, color: Colors.white, size: 28),
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
      children: List.generate(13, (i) {
        final h = 8 + (level * 120 * (1 - (i - 6).abs() / 7));
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 6,
          height: h.clamp(8.0, 100.0),
          decoration: BoxDecoration(
              color: color.withOpacity((h / 100).clamp(0.3, 1.0)),
              borderRadius: BorderRadius.circular(10)),
        );
      }),
    );
  }
}