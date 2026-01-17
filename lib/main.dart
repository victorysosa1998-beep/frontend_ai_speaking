import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Added for the animation timer
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.microphone.request();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: GistPartnerApp()));
}

class GistPartnerApp extends StatefulWidget {
  const GistPartnerApp({super.key});
  @override
  State<GistPartnerApp> createState() => _GistPartnerAppState();
}

class _GistPartnerAppState extends State<GistPartnerApp> {
  Room? _room;
  bool _isConnected = false;
  bool _isLoading = false;
  String _selectedVoice = "female"; 

  // Wave States
  double _userVolume = 0;
  double _aiVolume = 0;
  Timer? _animTimer;

  final String _backendIp = "192.168.236.157";
  final String _liveKitUrl = "wss://key-5d1ldsh2.livekit.cloud";

  // Starts the loop to check volume levels
  void _startWaveAnimation() {
    _animTimer?.cancel();
    _animTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_room != null && _isConnected) {
        setState(() {
          // Monitor Local (You)
          _userVolume = _room!.localParticipant?.audioLevel ?? 0;
          
          // Monitor Remote (AI)
          final remote = _room!.remoteParticipants.values.firstOrNull;
          _aiVolume = remote?.audioLevel ?? 0;
        });
      }
    });
  }

  Future<void> _handleCall() async {
    if (_isConnected) {
      _animTimer?.cancel();
      await _room?.disconnect();
      setState(() {
        _isConnected = false;
        _userVolume = 0;
        _aiVolume = 0;
      });
    } else {
      await _connect();
    }
  }

  Future<void> _connect() async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('http://$_backendIp:8000/get_token?gender=$_selectedVoice');
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      final token = jsonDecode(resp.body)['token'];

      _room = Room();
      await _room!.connect(_liveKitUrl, token, roomOptions: const RoomOptions(adaptiveStream: true));
      await _room!.localParticipant?.setMicrophoneEnabled(true);

      _startWaveAnimation(); // Start the wave moving
      setState(() {
        _isConnected = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Connection failed: $e");
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AI Wave (Appears when connected)
            if (_isConnected) ...[
              const Text("AI PARTNER", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              WaveVisualizer(level: _aiVolume, color: Colors.blue),
              const SizedBox(height: 40),
            ],

            Icon(Icons.mic, color: _isConnected ? Colors.green : Colors.grey, size: 80),
            
            // User Wave (Appears when connected)
            if (_isConnected) ...[
              const SizedBox(height: 10),
              WaveVisualizer(level: _userVolume, color: Colors.green),
              const Text("YOU", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ],

            const SizedBox(height: 40),
            if (!_isConnected) _voiceSelector(),
            const SizedBox(height: 40),
            _isLoading 
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _handleCall,
                  style: ElevatedButton.styleFrom(backgroundColor: _isConnected ? Colors.red : Colors.blue),
                  child: Text(_isConnected ? "END CALL" : "START GIST"),
                ),
          ],
        ),
      ),
    );
  }

  Widget _voiceSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(label: const Text("Brother"), selected: _selectedVoice == "male", onSelected: (s) => setState(() => _selectedVoice = "male")),
        const SizedBox(width: 20),
        ChoiceChip(label: const Text("Sister"), selected: _selectedVoice == "female", onSelected: (s) => setState(() => _selectedVoice = "female")),
      ],
    );
  }
}

// Custom Wave Widget
class WaveVisualizer extends StatelessWidget {
  final double level;
  final Color color;
  const WaveVisualizer({super.key, required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(9, (index) {
          // Calculate height: Base (4) + (Volume Level * Max Height)
          // index % 3 adds some variation so the bars don't look like a solid block
          double h = 4 + (level * 50 * (1.0 - (index - 4).abs() / 5));
          return AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 8,
            height: h,
            decoration: BoxDecoration(
              color: color.withOpacity(0.7),
              borderRadius: BorderRadius.circular(5),
            ),
          );
        }),
      ),
    );
  }
}