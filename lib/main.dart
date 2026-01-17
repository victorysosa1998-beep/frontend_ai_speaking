import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.microphone.request();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: SelectionScreen()));
}

// =================== SELECTION SCREEN ===================
class SelectionScreen extends StatefulWidget {
  const SelectionScreen({super.key});
  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  String _selectedVoice = "female";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent.withOpacity(0.1), Colors.black],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 50),
            const SizedBox(height: 20),
            const Text("Gist Partner",
                style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
            const Text("Choose your AI companion",
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _partnerCard("Brother", "male", Icons.face_retouching_natural),
                const SizedBox(width: 25),
                _partnerCard("Sister", "female", Icons.face_6),
              ],
            ),
            const SizedBox(height: 80),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CallScreen(voice: _selectedVoice)),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Text("START GISTING",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _partnerCard(String name, String value, IconData icon) {
    final isSelected = _selectedVoice == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedVoice = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withOpacity(0.15)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: isSelected ? Colors.blueAccent : Colors.white10, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 60, color: isSelected ? Colors.blueAccent : Colors.white24),
            const SizedBox(height: 15),
            Text(name,
                style: TextStyle(color: isSelected ? Colors.white : Colors.white24)),
          ],
        ),
      ),
    );
  }
}

// =================== CALL SCREEN ===================
class CallScreen extends StatefulWidget {
  final String voice;
  const CallScreen({super.key, required this.voice});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Room? _room;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;

  double _userLevel = 0;
  double _aiLevel = 0;
  Timer? _statsTimer;
  Timer? _durationTimer;
  int _seconds = 0;

  // Transcript state
  String _lastTranscript = "Waiting for gist...";

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      final res = await http.get(
        Uri.parse("http://192.168.236.157:8000/get_token?gender=${widget.voice}"),
      );
      final data = jsonDecode(res.body);
      final String token = data["token"];

      _room = Room();

      final listener = _room!.createListener();

      // Listen for AI Audio
      listener.on<TrackSubscribedEvent>((event) {
        if (event.track is RemoteAudioTrack) {
          event.track.start();
        }
      });

      // ✅ Handle Data Packets (Transcripts) from Backend
      listener.on<DataReceivedEvent>((event) {
        final text = utf8.decode(event.data);
        setState(() {
          if (event.topic == "transcript:user") {
            _lastTranscript = "You: $text";
          } else if (event.topic == "transcript:ai") {
            _lastTranscript = "AI: $text";
          }
        });
      });

      // ✅ Using the token provided by backend (which contains the room info)
      await _room!.connect(
        "wss://key-5d1ldsh2.livekit.cloud",
        token,
      );

      await _room!.localParticipant?.setMicrophoneEnabled(true);
      await _room!.setSpeakerOn(true);

      _startTimers();
      setState(() => _isConnected = true);
    } catch (e) {
      debugPrint("Connection error: $e");
      if (mounted) Navigator.pop(context);
    }
  }

  void _startTimers() {
    _statsTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_room == null) return;
      setState(() {
        _userLevel = _room!.localParticipant?.audioLevel ?? 0;
        final remote = _room!.remoteParticipants.values.isNotEmpty
            ? _room!.remoteParticipants.values.first
            : null;
        _aiLevel = remote?.audioLevel ?? 0;
      });
    });

    _durationTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
  }

  String _time() =>
      "${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}";

  @override
  void dispose() {
    _statsTimer?.cancel();
    _durationTimer?.cancel();
    _room?.disconnect();
    _room?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(_isConnected ? _time() : "Connecting...",
                style: const TextStyle(color: Colors.white54, fontFamily: 'monospace')),
            
            // ✅ Transcript Display Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  _lastTranscript,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic),
                ),
              ),
            ),
            
            const Spacer(),
            Text(widget.voice == "male" ? "Brother AI" : "Sister AI",
                style: const TextStyle(
                    color: Colors.blueAccent, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            WaveWidget(level: _aiLevel, color: Colors.blueAccent),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Icon(Icons.swap_vert, color: Colors.white10),
            ),
            WaveWidget(level: _isMuted ? 0 : _userLevel, color: Colors.greenAccent),
            const SizedBox(height: 20),
            Text(_isMuted ? "MIC MUTED" : "YOU ARE SPEAKING",
                style: TextStyle(color: _isMuted ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
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
                  _circle(Icons.call_end, false, () => Navigator.pop(context), red: true),
                  _circle(Icons.volume_up, _isSpeakerOn, () async {
                    setState(() => _isSpeakerOn = !_isSpeakerOn);
                    await _room!.setSpeakerOn(_isSpeakerOn);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(IconData icon, bool active, VoidCallback onTap, {bool red = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: red ? Colors.red : (active ? Colors.white12 : Colors.red.withOpacity(0.2)),
          border: Border.all(color: red ? Colors.transparent : Colors.white10),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

// =================== WAVE ===================
class WaveWidget extends StatelessWidget {
  final double level;
  final Color color;
  const WaveWidget({super.key, required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(13, (i) {
        final h = 8 + (level * 70 * (1 - (i - 6).abs() / 7));
        return AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 5,
          height: h,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        );
      }),
    );
  }
}