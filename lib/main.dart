import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';
import 'package:headphones_detection/headphones_detection.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Your local imports
import 'firebase_options.dart';
import 'login_page.dart';
import 'splashScreen.dart';
import 'voice_selection_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FCM BACKGROUND HANDLER
// Must be a top-level function — Flutter runs this in a separate isolate
// when a notification arrives while the app is terminated or in background.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("[FCM] Background: ${message.notification?.title} | type=${message.data['type']}");
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCAL NOTIFICATIONS
// Shows a heads-up banner when a notification arrives while app is in foreground.
// FCM does NOT show notification UI in foreground by default — this handles it.
// ─────────────────────────────────────────────────────────────────────────────
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

// One channel per category — users can control each in Android settings
const _channelReminder = AndroidNotificationChannel(
  'sympy_reminders',
  'Chat Reminders',
  description: 'Reminders to come back and chat with your AI companion',
  importance: Importance.defaultImportance,
  playSound: true,
);
const _channelMessage = AndroidNotificationChannel(
  'sympy_messages',
  'AI Messages',
  description: 'New messages from your AI companion',
  importance: Importance.high,
  playSound: true,
);
const _channelCredits = AndroidNotificationChannel(
  'sympy_credits',
  'Credits & Billing',
  description: 'Credit balance and billing alerts',
  importance: Importance.high,
  playSound: true,
);
const _channelPromo = AndroidNotificationChannel(
  'sympy_promos',
  'Offers & Updates',
  description: 'Promotional offers and app updates from Sympy',
  importance: Importance.low,
  playSound: false,
);

// ─────────────────────────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }

  // Register background handler BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Create all Android notification channels
  final androidPlugin = _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(_channelReminder);
  await androidPlugin?.createNotificationChannel(_channelMessage);
  await androidPlugin?.createNotificationChannel(_channelCredits);
  await androidPlugin?.createNotificationChannel(_channelPromo);

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

    // 4. Push Notifications
    await _initFCM();
  }

  // ─────────────────────────────────────────────────────────────────
  // FCM SETUP
  // ─────────────────────────────────────────────────────────────────
  Future<void> _initFCM() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission — required on iOS and Android 13+
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint("[FCM] Permission: ${settings.authorizationStatus}");

      // Get token and save to Firestore for targeted pushes from backend
      final token = await messaging.getToken();
      debugPrint("[FCM] Token: $token");
      if (token != null) _saveFcmToken(token);

      // Refresh token when it rotates
      messaging.onTokenRefresh.listen(_saveFcmToken);

      // Init local notifications for foreground heads-up display
      const androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint("[FCM] Notification tapped: ${details.payload}");
          if (details.payload != null) {
            _handleNotificationTap({'route': details.payload!});
          }
        },
      );

      // ── Foreground messages ─────────────────────────────────────
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("[FCM] Foreground: ${message.notification?.title}");
        final notification = message.notification;
        final android = message.notification?.android;
        if (notification == null || android == null) return;

        // Pick channel based on notification type sent from backend
        final type = message.data['type'] ?? 'message';
        AndroidNotificationChannel channel;
        if (type == 'reminder') {
          channel = _channelReminder;
        } else if (type == 'credits') {
          channel = _channelCredits;
        } else if (type == 'promo') {
          channel = _channelPromo;
        } else {
          channel = _channelMessage;
        }

        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: channel.importance,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: message.data['route'],
        );
      });

      // ── Background → foreground (app was minimised) ─────────────
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint("[FCM] Opened from background: ${message.data}");
        _handleNotificationTap(message.data);
      });

      // ── Terminated → opened via notification ────────────────────
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        debugPrint("[FCM] Launched from terminated: ${initial.data}");
        await Future.delayed(const Duration(milliseconds: 600));
        _handleNotificationTap(initial.data);
      }
    } catch (e) {
      debugPrint("[FCM] Setup error (non-fatal): $e");
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final route = data['route'] ?? '';
    debugPrint("[FCM] Tap route: $route");
    // Extend this with Navigator pushes based on route field:
    // if (route == 'upgrade') Navigator.push(context, MaterialPageRoute(builder: (_) => UpgradePage()));
    // if (route == 'chat') Navigator.push(context, MaterialPageRoute(builder: (_) => SympyChatPage(...)));
  }

  Future<void> _saveFcmToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("[FCM] Skipping token save — no user logged in");
        return;
      }
      // Use set+merge instead of update.
      // update() fails with PERMISSION_DENIED if fcm_token field doesn't exist yet.
      // set+merge creates the field if missing and updates it if present —
      // and it's allowed by the Firestore security rules that permit the user
      // to write their own document.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'fcm_token': token,
        'fcm_updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint("[FCM] Token saved for ${user.uid}");
    } catch (e) {
      debugPrint("[FCM] Token save failed (non-fatal): $e");
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(iconTheme: const IconThemeData(color: Colors.white)),
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                  child: CircularProgressIndicator(color: Colors.white)),
            );
          }

          if (!snapshot.hasData) {
            return const LoginPage();
          }

          Future.delayed(
            const Duration(seconds: 2),
            () => _syncUserToFirestore(snapshot.data!),
          );

          return _buildHomeScreen();
        },
      ),
    );
  }

  Widget _buildHomeScreen() {
    if (_micGranted == false) {
      return PermissionDeniedScreen();
    }
    return WelcomeScreen();
  }

  Future<void> _syncUserToFirestore(User user) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        debugPrint("[SYNC] Skipping — user no longer signed in");
        return;
      }
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await userDoc.get();
      if (!doc.exists) {
        await userDoc.set({
          'credits': 0,
          'is_premium': false,
          'created_at': FieldValue.serverTimestamp(),
          'email': user.email,
          'free_seconds_remaining': 180,
        });
        debugPrint("[SYNC] New user document created for ${user.uid}");
      } else {
        debugPrint("[SYNC] User document already exists for ${user.uid}");
      }
    } catch (e) {
      debugPrint("[SYNC] Firestore sync failed (non-fatal): $e");
    }
  }
}

// ------------------------------------------------------------------
// REUSABLE SCREENS & WIDGETS
// ------------------------------------------------------------------

class PermissionDeniedScreen extends StatelessWidget {
  const PermissionDeniedScreen({super.key});

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
                    MaterialPageRoute(
                        builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            "Please log in again to delete account.")),
                  );
                }
              }
            },
            child:
                const Text("Delete", style: TextStyle(color: Colors.red)),
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
          style:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),
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
                  leading: const Icon(Icons.delete_forever,
                      color: Colors.redAccent),
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

  Widget _buildInfoRow(String label, String value,
      {required bool showArrow}) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 15)),
          if (showArrow) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: Colors.white24, size: 20),
          ]
        ],
      ),
    );
  }
}