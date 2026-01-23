import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';
import 'package:headphones_detection/headphones_detection.dart';
import 'splashScreen.dart';
import 'voice_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize audio session safely
  try {
    final session = await AudioSession.instance;
    await session.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth, // Bluetooth allowed
        avAudioSessionMode: AVAudioSessionMode.voiceChat, // Earpiece default
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
      ),
    );

    // Activate session
    await session.setActive(true);
  } catch (e) {
    debugPrint(
      "Audio session setup failed (ignored safely, may be emulator): $e",
    );
  }

  // Request microphone permission
  bool micGranted = false;
  try {
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      final result = await Permission.microphone.request();
      micGranted = result.isGranted;
    } else {
      micGranted = true;
    }
  } catch (e) {
    debugPrint("Microphone permission request failed: $e");
  }

  // ✅ Headset detection (initial)
  bool isHeadsetConnected = false;
  try {
    isHeadsetConnected = await HeadphonesDetection.isHeadphonesConnected();
  } catch (_) {}

  // Listen for changes (optional, can use inside CallScreen)
  HeadphonesDetection.headphonesStream.listen((bool connected) {
    debugPrint("Headset connected: $connected");
    // You can notify CallScreen or other widgets here if needed
  });

  runApp(
    MaterialApp(
      theme: ThemeData(iconTheme: const IconThemeData(color: Colors.white)),
      debugShowCheckedModeBanner: false,
      home: micGranted ? WelcomeScreen() : PermissionDeniedScreen(),
    ),
  );
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

// Optional: example speaker toggle button (kept unchanged)
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
 