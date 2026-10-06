import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audio_session/audio_session.dart';
import 'package:headphones_detection/headphones_detection.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

// Your local imports
import 'firebase_options.dart';
import 'login_page.dart';
import 'social_home.dart';
import 'group_call_page.dart';
import 'app_brand.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FCM BACKGROUND HANDLER
// Must be a top-level function — Flutter runs this in a separate isolate
// when a notification arrives while the app is terminated or in background.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    "[FCM] Background: ${message.notification?.title} | type=${message.data['type']}",
  );
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
  description: 'Promotional offers and app updates from Ovie',
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
        AndroidFlutterLocalNotificationsPlugin
      >();
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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool? _micGranted;
  String? _lastSyncedUid;

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

    // 3. Do not request microphone permission during app startup.
    // Chat and Fun Zone work without a microphone. The call screen requests
    // RECORD_AUDIO only when the user actually starts a voice/video call.
    if (mounted) {
      setState(() => _micGranted = true);
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
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint("[FCM] Notification tapped: ${details.payload}");
          if (details.payload != null) {
            try {
              final parsed = jsonDecode(details.payload!);
              _handleNotificationTap(Map<String, dynamic>.from(parsed));
            } catch (_) {
              _handleNotificationTap({'route': details.payload!});
            }
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
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: channel.importance,
              priority: Priority.high,
              icon: '@drawable/ic_stat_sympy',
            ),
          ),
          payload: jsonEncode(message.data),
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
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    if (route == 'group_call') {
      final invite = data['invite_code']?.toString() ?? '';
      if (invite.isEmpty) return;
      nav.push(
        MaterialPageRoute(
          builder: (_) => GroupCallPage(
            voice: data['voice']?.toString() ?? 'female',
            vibe: data['vibe']?.toString() ?? 'Gist',
            groupId: data['group_id']?.toString(),
            inviteCode: invite,
            autoStart: true,
          ),
        ),
      );
    }
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
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
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
    const seed = Color(0xFF8B5CF6);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: OvieBrand.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: OvieBrand.background,
        canvasColor: OvieBrand.background,
        splashFactory: InkSparkle.splashFactory,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: const CardThemeData(
          color: OvieBrand.card,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: OvieBrand.primary, width: 1.2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const LoginPage();
          }

          final user = snapshot.data!;
          if (_lastSyncedUid != user.uid) {
            _lastSyncedUid = user.uid;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _syncUserToFirestore(user);
            });
          }

          return _buildHomeScreen();
        },
      ),
    );
  }

  Widget _buildHomeScreen() {
    // Microphone permission is requested by the call UI, not at startup.
    // Never block the main app because startup permission state is unavailable.
    return const SocialHome();
  }

  Future<void> _syncUserToFirestore(User user) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        debugPrint("[SYNC] Skipping — user no longer signed in");
        return;
      }
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final doc = await userDoc.get();
      if (!doc.exists) {
        final name = user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'Ovie User';
        // Server-owned billing/quota fields are intentionally not written by the client.
        // The backend creates/initializes those fields using Firebase Admin SDK.
        await userDoc.set({
          'email': user.email,
          'display_name': name,
          'bio': 'Finding my vibe on Ovie ✨',
          'photo_url': user.photoURL,
          'friends_count': 0,
          'followers_count': 0,
          'following_count': 0,
          'posts_count': 0,
          'status_count': 0,
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
        title: const Text(
          "Delete Account?",
          style: TextStyle(color: Colors.white),
        ),
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
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please log in again to delete account."),
                    ),
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
    final String initial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : "?";

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
                      fontWeight: FontWeight.bold,
                    ),
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
                  endIndent: 20,
                ),
                _buildInfoRow("Email", email, showArrow: false),
                const Divider(
                  color: Colors.white10,
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    "Delete Account",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    "Permanently remove your data",
                    style: TextStyle(color: Colors.white38),
                  ),
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
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                      (route) => false,
                    );
                  }
                },
                child: const Text(
                  "Log out",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(color: Colors.white38, fontSize: 15),
          ),
          if (showArrow) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ],
      ),
    );
  }
}
