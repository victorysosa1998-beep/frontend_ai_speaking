import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';
import 'package:headphones_detection/headphones_detection.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Your local imports
import 'firebase_options.dart';
import 'login_page.dart';
import 'splashScreen.dart';
import 'voice_selection_screen.dart';

void main() async {
  // Ensure engine is ready before any async calls
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
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
    // Run all setup tasks without blocking the UI thread
    _initializeAppLogic();
  }

  Future<void> _initializeAppLogic() async {
    // 1. Audio Session Configuration
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

    // 2. Headset detection
    try {
      await HeadphonesDetection.isHeadphonesConnected();
      HeadphonesDetection.headphonesStream.listen((bool connected) {
        debugPrint("Headset connected: $connected");
      });
    } catch (_) {}

    // 3. Microphone Permission Request
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
      // The StreamBuilder listens for login/logout events
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // While checking auth status, show a loader
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body:
                  Center(child: CircularProgressIndicator(color: Colors.white)),
            );
          }

          // If NOT logged in, show the LoginPage
          if (!snapshot.hasData) {
            return const LoginPage();
          }

          // If logged in, check permissions and show the main app
          return _buildHomeScreen();
        },
      ),
    );
  }

  Widget _buildHomeScreen() {
    // Show loading while permission state is null
    if (_micGranted == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // Direct user to WelcomeScreen if permission is granted
    return _micGranted! ? WelcomeScreen() : PermissionDeniedScreen();
  }


Future<void> _syncUserToFirestore(User user) async {
  final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
  
  final doc = await userDoc.get();
  if (!doc.exists) {
    // This is a new user! Give them the 50 free credits
    await userDoc.set({
      'credits': 50,
      'is_premium': false,
      'created_at': FieldValue.serverTimestamp(),
      'email': user.email,
    });
  }
}

}

// ------------------------------------------------------------------
// REUSABLE SCREENS & WIDGETS
// ------------------------------------------------------------------

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
        debugPrint("Speaker toggle pressed.");
      },
    );
  }
}

// ------------------------------------------------------------------
// PROFILE PAGE WITH FIXED LOGOUT & DELETE ACCOUNT
// ------------------------------------------------------------------

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _confirmDelete(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Delete Account?",
            style: TextStyle(color: Colors.white)),
        content: const Text(
          "This will permanently delete your profile and chat history from our servers. This action cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseAuth.instance.currentUser?.delete();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                }
              } catch (e) {
                // Handle re-authentication if necessary
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text("Please log in again to delete account.")),
                  );
                }
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String displayName = user?.displayName ?? "";
    final String email = user?.email ?? "";
    final String initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : "?";

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "Account",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),
          // PROFILE PICTURE
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: const Color(0xFF004D40),
                  child: Text(
                    initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Tap to change profile picture",
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          // INFO CARD
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _buildInfoRow("Name", displayName, showArrow: true),
                const Divider(
                    color: Colors.white10,
                    height: 1,
                    indent: 20,
                    endIndent: 20),
                _buildInfoRow("Email", email, showArrow: false),
                const Divider(
                    color: Colors.white10,
                    height: 1,
                    indent: 20,
                    endIndent: 20),
                ListTile(
                  leading:
                      const Icon(Icons.delete_forever, color: Colors.redAccent),
                  title: const Text("Delete Account",
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold)),
                  subtitle: const Text("Permanently remove your data",
                      style: TextStyle(color: Colors.white38)),
                  onTap: () => _confirmDelete(context),
                ),
              ],
            ),
          ),
          const Spacer(),
          // LOGOUT BUTTON
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1C1E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const LoginPage()),
                      (route) => false,
                    );
                  }
                },
                child: const Text(
                  "Log out",
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {required bool showArrow}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value,
              style: const TextStyle(color: Colors.white38, fontSize: 15)),
          if (showArrow) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ]
        ],
      ),
    );
  }
}
