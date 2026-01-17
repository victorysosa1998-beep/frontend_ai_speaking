// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize LiveKit globally (Handles Android audio routing)
  await LiveKitClient.initialize();

  runApp(const GistApp());
}

class GistApp extends StatelessWidget {
  const GistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GistScreen(),
    );
  }
}

class GistScreen extends StatefulWidget {
  const GistScreen({super.key});

  @override
  State<GistScreen> createState() => _GistScreenState();
}

class _GistScreenState extends State<GistScreen> with WidgetsBindingObserver {
  Room? _room;
  bool _isConnecting = false;
  bool _isLive = false;

  // Your LiveKit cloud URL and local token server
  static const String _serverUrl = 'wss://key-5d1ldsh2.livekit.cloud';
  static const String _tokenEndpoint = 'http://192.168.236.157:8000/get_token';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disconnectInternal();
    super.dispose();
  }

  Future<void> connectToAgent() async {
    if (_isConnecting || _isLive) return;
    setState(() => _isConnecting = true);

    try {
      // A. Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        _showError('Microphone permission is required.');
        return;
      }

      // B. Fetch token from FastAPI server
      debugPrint('Fetching token...');
      final response = await http
          .get(Uri.parse(_tokenEndpoint))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final token = jsonDecode(response.body)['token'];

      // C. Connect to the LiveKit room
      final room = Room();

      // Listen for remote audio tracks (AI TTS)
      room.events.listen((event) {
        if (event is TrackSubscribedEvent) {
          final track = event.track;
          if (track is RemoteAudioTrack) {
            track.start(); // Auto-play AI audio
            debugPrint('Remote audio started: ${event.publication.name}');
          }
        }
      });

      await room.connect(
        _serverUrl,
        token,
        connectOptions: const ConnectOptions(
          autoSubscribe: true, // auto-subscribe remote tracks
          rtcConfiguration: RTCConfiguration(
            iceTransportPolicy: RTCIceTransportPolicy.all,
          ),
        ),
      );

      // D. Publish local mic track
      await room.localParticipant?.setMicrophoneEnabled(true);

      setState(() {
        _room = room;
        _isLive = true;
      });

      debugPrint('🎉 Connected to LiveKit and ready to gist!');
    } catch (e) {
      _showError('Connection failed: $e');
      debugPrint('❌ Error: $e');
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  Future<void> disconnect() async {
    await _disconnectInternal();
    setState(() => _isLive = false);
  }

  Future<void> _disconnectInternal() async {
    try {
      await _room?.disconnect();
      await _room?.dispose();
    } catch (_) {}
    _room = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('2026 Gist Partner'),
        backgroundColor: Colors.blueGrey.shade900,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isLive ? Icons.record_voice_over : Icons.mic_none,
              size: 120,
              color: _isLive ? Colors.greenAccent : Colors.white24,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isConnecting
                  ? null
                  : (_isLive ? disconnect : connectToAgent),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLive ? Colors.redAccent : Colors.blueAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isLive ? 'End Gist Session' : 'Start Gist Session'),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
