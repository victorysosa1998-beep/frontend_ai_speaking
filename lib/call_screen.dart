import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:http/http.dart' as http;
import 'package:headphones_detection/headphones_detection.dart';

class CallScreen extends StatefulWidget {
  final String voice;
  final String vibe;
  const CallScreen({super.key, required this.voice, required this.vibe});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false; // loudspeaker toggle (works as before)
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

  late List<String> _displayTexts;
  int _textIndex = 0;
  Timer? _textFadeTimer;

  // ✅ Headset detection
  bool _isHeadsetConnected = false;

  @override
  void initState() {
    super.initState();
    _displayTexts = [
      widget.voice == "male" ? "Buddy" : "Missy",
      "Cooking up some major vibes... 🍳",
      "Checking the street for update... 🤫",
      "Abeg hold on, I de find words... 💭",
      "Vibe check in progress... 🔥",
      "Sharpening my tongue... 👅",
    ];
    _startTextRotation();
    _connect();
    _listenHeadset(); // ✅ start headset listener
  }

  // Headset detection setup
  void _listenHeadset() async {
    // Initial state
    try {
      bool connected = await HeadphonesDetection.isHeadphonesConnected();
      setState(() => _isHeadsetConnected = connected);
    } catch (_) {}

    // Listen for changes
    HeadphonesDetection.headphonesStream.listen((bool connected) {
      setState(() => _isHeadsetConnected = connected);
      _updateAudioRouting();
    });
  }

  void _updateAudioRouting() async {
    if (_room == null) return;

    if (_isHeadsetConnected) {
      // ✅ Headset connected → force audio to headset, mute earpiece
      await _room!.setSpeakerOn(false);
    } else {
      // ✅ No headset → use your normal loudspeaker toggle
      await _room!.setSpeakerOn(_isSpeakerOn);
    }
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

  Future<void> _connect() async {
    setState(() {
      _hasError = false;
      _lastTranscript = "Connecting to sympy...";
    });

    try {
      _log("HTTP", "Requesting token from server...");
      final res = await http
          .get(
            Uri.parse(
              "http://192.168.253.157:8000/get_token?gender=${widget.voice}&vibe=${widget.vibe}",
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) throw "Server Error: ${res.statusCode}";
      final data = jsonDecode(res.body);
      final String token = data["token"];

      _room = Room();
      _listener = _room!.createListener();

      _listener!
        ..on<TrackSubscribedEvent>((event) async {
          _log("LiveKit", "Track subscribed: ${event.track.sid}");
          if (event.track is RemoteAudioTrack) await event.track.start();
        })
        ..on<TrackSubscriptionExceptionEvent>((event) {
          _log("LiveKit", "Subscription Exception: ${event.reason}");
        })
        ..on<AudioPlaybackStatusChanged>((event) async {
          if (!_room!.canPlaybackAudio) await _room!.startAudio();
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
        ..on<RoomDisconnectedEvent>((event) {
          _log("LiveKit", "Disconnected.");
          _safeExit();
        });

      _log("LiveKit", "Connecting to wss://key-5d1ldsh2.livekit.cloud");

      await _room!.connect(
        "wss://key-5d1ldsh2.livekit.cloud",
        token,
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );

      await _room!.startAudio();
      await _room!.localParticipant?.setMicrophoneEnabled(true);

      // ✅ Apply audio routing after connection
      _updateAudioRouting();

      _startTimers();
      if (!mounted) return;
      setState(() {
        _isConnected = true;
        _lastTranscript = "Listening...";
      });
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
        final remote = _room!.remoteParticipants.values.isNotEmpty
            ? _room!.remoteParticipants.values.first
            : null;
        _aiLevel = remote?.audioLevel ?? 0;
      });
    });
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  void _safeExit() {
    if (_exited) return;
    _exited = true;
    _statsTimer?.cancel();
    _durationTimer?.cancel();
    _textFadeTimer?.cancel();
    _listener?.dispose();
    _room?.disconnect();
    if (mounted) Navigator.pop(context);
  }

  String _time() =>
      "${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}";

  @override
  void dispose() {
    _safeExit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color.fromARGB(255, 32, 139, 227),
              Color.fromARGB(255, 44, 11, 50),
            ],
          ),
        ),
        child: SafeArea(
          child: _hasError ? _buildErrorView() : _buildCallView(),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 80),
          const SizedBox(height: 10),
          const Text(
            "Connection Failed",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            "Check Your Internet connection .",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _connect, child: const Text("Try Again")),
          TextButton(
            onPressed: _safeExit,
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white38),
            ),
          ),
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
            Text(
              _isConnected ? _time() : "Connecting...",
              style: const TextStyle(
                color: Colors.white54,
                fontFamily: 'monospace',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  _lastTranscript,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              child: Text(
                _displayTexts[_textIndex],
                key: ValueKey<int>(_textIndex),
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Vibe: ${widget.vibe}",
              style: const TextStyle(
                color: Color.fromARGB(255, 232, 229, 229),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 30),
            WaveWidget(
              level: _aiLevel,
              color: const Color.fromARGB(255, 89, 148, 249),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Icon(Icons.compare_arrows, color: Colors.white10),
            ),
            WaveWidget(
              level: _isMuted ? 0 : _userLevel,
              color: const Color.fromARGB(255, 126, 246, 188),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _circle(Icons.mic, !_isMuted, () async {
                    setState(() => _isMuted = !_isMuted);
                    await _room!.localParticipant?.setMicrophoneEnabled(
                      !_isMuted,
                    );
                  }),
                  _circle(Icons.call_end, false, _safeExit, red: true),
                  _circle(Icons.volume_up, _isSpeakerOn, () async {
                    setState(() => _isSpeakerOn = !_isSpeakerOn);
                    if (!_isHeadsetConnected) {
                      await _room!.setSpeakerOn(_isSpeakerOn);
                    }
                  }),
                ],
              ),
            ),
          ],
        ),
        if (_activeEmoji != null)
          Center(
            child: Text(_activeEmoji!, style: const TextStyle(fontSize: 120)),
          ),
      ],
    );
  }

  Widget _circle(
    IconData icon,
    bool active,
    VoidCallback onTap, {
    bool red = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: red
              ? Colors.red
              : (active ? Colors.white12 : Colors.red.withOpacity(0.2)),
        ),
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
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}
