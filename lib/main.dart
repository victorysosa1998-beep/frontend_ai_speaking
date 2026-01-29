import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';
import 'package:headphones_detection/headphones_detection.dart';
import 'splashScreen.dart';
import 'voice_selection_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  // Ensure engine is ready
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase immediately
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool? _micGranted;

  @override
  void initState() {
    super.initState();
    // Run all setup tasks without blocking the main thread
    _initializeAppLogic();
  }

  Future<void> _initializeAppLogic() async {
    // 1. Handle Anonymous Login
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
        debugPrint("✅ Firebase anonymous login successful.");
      }
    } catch (e) {
      debugPrint("❌ Firebase login failed: $e");
    }

    // 2. Initialize Audio Session
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
        ),
      );
      await session.setActive(true);
    } catch (e) {
      debugPrint("Audio session setup failed: $e");
    }

    // 3. Headset detection
    try {
      await HeadphonesDetection.isHeadphonesConnected();
      HeadphonesDetection.headphonesStream.listen((bool connected) {
        debugPrint("Headset connected: $connected");
      });
    } catch (_) {}

    // 4. Permission Request (This determines the screen)
    bool granted = false;
    try {
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        final result = await Permission.microphone.request();
        granted = result.isGranted;
      } else {
        granted = true;
      }
    } catch (e) {
      debugPrint("Microphone permission failed: $e");
    }

    if (mounted) {
      setState(() {
        _micGranted = granted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(iconTheme: const IconThemeData(color: Colors.white)),
      debugShowCheckedModeBanner: false,
      home: _buildHomeScreen(),
    );
  }

  Widget _buildHomeScreen() {
    // Show a loading spinner while waiting for permission check
    if (_micGranted == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return _micGranted! ? WelcomeScreen() : PermissionDeniedScreen();
  }
}

// Screen for denied microphone permission
class PermissionDeniedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic_off, size: 60, color: Colors.redAccent),
              const SizedBox(height: 20),
              const Text(
                "Microphone permission is required to use this app.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async => await openAppSettings(),
                child: const Text("Open Settings"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Optional: example speaker toggle button
class SpeakerToggleButton extends StatefulWidget {
  const SpeakerToggleButton({super.key});

  @override
  State<SpeakerToggleButton> createState() => _SpeakerToggleButtonState();
}

class _SpeakerToggleButtonState extends State<SpeakerToggleButton> {
  bool isSpeakerOn = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(isSpeakerOn ? Icons.volume_up : Icons.volume_down),
      onPressed: () {
        setState(() => isSpeakerOn = !isSpeakerOn);
        debugPrint(
          "Speaker toggle pressed. Implement platform-specific routing here.",
        );
      },
    );
  }
}