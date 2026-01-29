import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
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

  late List<String> _displayTexts;
  int _textIndex = 0;
  Timer? _textFadeTimer;

  @override
  void initState() {
    super.initState();
    _displayTexts = [
      "Missy",
      "Cooking up some major vibes... 🍳",
      "Checking the street for update... 🤫",
      "Abeg hold on, I dey find words... 🧐",
      "Vibe check in progress... 🔋",
      "Sharpening my tongue... 🔪",
    ];

    _startTextRotation();
    _connect();
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
      // Small delay to let previous audio sessions fully die
      await Future.delayed(const Duration(milliseconds: 800)); 

      final url = "https://web-production-6c359.up.railway.app/get_token?gender=female&vibe=${widget.vibe}";
      final res = await http
          .get(Uri.parse(url), headers: {"X-API-KEY": AppSecrets.appApiKey})
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) throw "API Error: ${res.statusCode}";
      final data = jsonDecode(res.body);
      final String token = data["token"];

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
            Timer(const Duration(seconds: 2), () => setState(() => _activeEmoji = null));
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
          _lastTranscript = "Listening...";
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
      if (mounted) setState(() => _seconds++);
    });
  }

  Future<void> _safeExit() async {
    if (_exited) return;
    _exited = true;

    _statsTimer?.cancel();
    _durationTimer?.cancel();
    _textFadeTimer?.cancel();

    try {
      _log("EXIT", "Full Cleanup");

      if (_room != null) {
        // 1. Unpublish everything from the local participant
        await _room!.localParticipant?.unpublishAllTracks();
        
        // 2. Disconnect the room
        await _room!.disconnect();
        
        // 3. Dispose the listener and room
        await _listener?.dispose();
        await _room!.dispose();
      }
      _room = null;
      
    } catch (e) {
      _log("EXIT_ERROR", e);
    }

    if (mounted) Navigator.pop(context);
  }

  String _time() => "${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}";

  @override
  void dispose() {
    if (!_exited) _safeExit();
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
          const Text("Connection Failed", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
            Text(_isConnected ? _time() : "Connecting...", style: const TextStyle(color: Colors.white54, fontFamily: 'monospace')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                child: Text(_lastTranscript, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic)),
              ),
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2)),
              child: ClipOval(child: Image.asset(widget.imagePath, width: 100, height: 100, fit: BoxFit.cover)),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              child: Text(_displayTexts[_textIndex], key: ValueKey<int>(_textIndex), style: const TextStyle(color: Colors.blueAccent, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            Text("Vibe: ${widget.vibe}", style: const TextStyle(color: Colors.white24, fontSize: 14)),
            const SizedBox(height: 30),
            WaveWidget(level: _aiLevel, color: Colors.blueAccent),
            const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Icon(Icons.compare_arrows, color: Colors.white10)),
            WaveWidget(level: _isMuted ? 0 : _userLevel, color: Colors.greenAccent),
            const SizedBox(height: 20),
            Text(_isMuted ? "MIC MUTED" : "YOU ARE SPEAKING", style: TextStyle(color: _isMuted ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
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
        if (_activeEmoji != null) Center(child: Text(_activeEmoji!, style: const TextStyle(fontSize: 120))),
      ],
    );
  }

  Widget _circle(IconData icon, bool active, VoidCallback onTap, {bool red = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(shape: BoxShape.circle, color: red ? Colors.red : (active ? Colors.white12 : Colors.red.withOpacity(0.2))),
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
          decoration: BoxDecoration(color: color.withOpacity((h / 100).clamp(0.3, 1.0)), borderRadius: BorderRadius.circular(10)),
        );
      }),
    );
  }
}