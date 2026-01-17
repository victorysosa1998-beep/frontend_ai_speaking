import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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

  final String _backendIp = "192.168.236.157"; // Your PC's LAN IP
  final String _liveKitUrl = "wss://key-5d1ldsh2.livekit.cloud"; // LiveKit Cloud URL

  Future<void> _handleCall() async {
    if (_isConnected) {
      await _room?.disconnect();
      setState(() => _isConnected = false);
    } else {
      await _connect();
    }
  }

  Future<void> _connect() async {
    setState(() => _isLoading = true);
    try {
      // Fetch token from backend with gender
      final uri = Uri.parse('http://$_backendIp:8000/get_token?gender=$_selectedVoice');
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      final token = jsonDecode(resp.body)['token'];

      _room = Room();
      print("🔗 Connecting to: $_liveKitUrl");

      await _room!.connect(_liveKitUrl, token, roomOptions: const RoomOptions(adaptiveStream: true));
      await _room!.localParticipant?.setMicrophoneEnabled(true);

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic, color: _isConnected ? Colors.green : Colors.grey, size: 100),
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
