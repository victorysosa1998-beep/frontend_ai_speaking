import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.microphone.request();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SelectionScreen(),
    ),
  );
}

class SelectionScreen extends StatefulWidget {
  const SelectionScreen({super.key});
  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  String _selectedVoice = "female";
  String _selectedVibe = "Chaotic"; // Default Vibe

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
            const SizedBox(height: 10),
            const Text(
              "Gist Partner",
              style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const Text("Choose your AI vibe", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 30),
            
            // NEW: VIBE SELECTION ROW
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _vibeChip("🤪 Chaotic", "Chaotic"),
                  _vibeChip("🧠 Savage", "Savage"),
                  _vibeChip("🧘 Calm", "Therapist"),
                  _vibeChip("😎 Flirty", "Flirty"),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _partnerCard("Brother", "male", Icons.face_retouching_natural),
                const SizedBox(width: 25),
                _partnerCard("Sister", "female", Icons.face_6),
              ],
            ),
            const SizedBox(height: 50),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(voice: _selectedVoice, vibe: _selectedVibe),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Text(
                  "START GISTING",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vibeChip(String label, String value) {
    final isSelected = _selectedVibe == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedVibe = value),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.white12,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.white : Colors.transparent),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white)),
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
          color: isSelected ? Colors.blueAccent.withOpacity(0.15) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white10, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 60, color: isSelected ? Colors.blueAccent : Colors.white24),
            const SizedBox(height: 15),
            Text(name, style: TextStyle(color: isSelected ? Colors.white : Colors.white24)),
          ],
        ),
      ),
    );
  }
}

class CallScreen extends StatefulWidget {
  final String voice;
  final String vibe; // NEW
  const CallScreen({super.key, required this.voice, required this.vibe});
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  double _userLevel = 0;
  double _aiLevel = 0;
  Timer? _statsTimer;
  Timer? _durationTimer;
  int _seconds = 0;
  String _lastTranscript = "Connecting to Gist Partner...";
  bool _exited = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      // UPDATED URL to send Vibe to Python
      final res = await http.get(
        Uri.parse("http://192.168.60.157:8000/get_token?gender=${widget.voice}&vibe=${widget.vibe}"),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);
      final String token = data["token"];

      _room = Room();
      _listener = _room!.createListener();

      _listener!
        ..on<TrackSubscribedEvent>((event) async {
          if (event.track is RemoteAudioTrack) {
            await event.track.start();
            await _room!.setSpeakerOn(true);
          }
        })
        ..on<AudioPlaybackStatusChanged>((event) async {
          if (!_room!.canPlaybackAudio) await _room!.startAudio();
        })
        ..on<DataReceivedEvent>((event) {
          final text = utf8.decode(event.data);
          if (!mounted) return;
          setState(() {
            if (event.topic == "transcript:ai") {
              _lastTranscript = "AI: $text";
            } else if (event.topic == "transcript:user") {
              _lastTranscript = "You: $text";
            } else {
              _lastTranscript = text;
            }
          });
        })
        ..on<RoomDisconnectedEvent>((event) => _safeExit());

      await _room!.connect("wss://key-5d1ldsh2.livekit.cloud", token);
      await _room!.startAudio();
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      await _room!.setSpeakerOn(true);

      _startTimers();
      if (!mounted) return;
      setState(() {
        _isConnected = true;
        _lastTranscript = "Listening...";
      });
    } catch (e) {
      if (mounted) _safeExit();
    }
  }

  // ... (Rest of your existing Flutter code for _startTimers, _safeExit, build, etc.)
  // Note: No changes needed to WaveWidget or your UI buttons logic.
  
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
    _listener?.dispose();
    _room?.disconnect();
    if (mounted) Navigator.pop(context);
  }

  String _time() => "${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}";

  @override
  void dispose() {
    _safeExit();
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
            Text(widget.voice == "male" ? "Brother AI" : "Sister AI", style: const TextStyle(color: Colors.blueAccent, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Vibe: ${widget.vibe}", style: const TextStyle(color: Colors.white24, fontSize: 14)), // SHOW VIBE
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
      ),
    );
  }

  Widget _circle(IconData icon, bool active, VoidCallback onTap, {bool red = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(shape: BoxShape.circle, color: red ? Colors.red : (active ? Colors.white12 : Colors.red.withOpacity(0.2)), border: Border.all(color: red ? Colors.transparent : Colors.white10)),
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