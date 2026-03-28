import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loveable/AboutPage.dart';
import 'package:loveable/profilePage.dart';
import 'package:loveable/secrets.dart';
import 'package:loveable/settings_page.dart';
import 'package:loveable/CreditService.dart';
import 'package:loveable/Upgradepage.dart';
import 'package:loveable/AdminPanelPage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'SympyChatPage.dart';

class MoodSelectionScreen extends StatefulWidget {
  final String imagePath;
  final String selectedImagePath;
  final String selectedVoice;

  const MoodSelectionScreen(
      {super.key,
      required this.imagePath,
      required this.selectedImagePath,
      required this.selectedVoice});

  @override
  State<MoodSelectionScreen> createState() => _MoodSelectionScreenState();
}

class _MoodSelectionScreenState extends State<MoodSelectionScreen>
    with TickerProviderStateMixin {
  String _selectedVibe = "Chaotic";
  late AnimationController _pulseController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String get _aiName => widget.selectedVoice == "male" ? "Buddy" : "Missy";

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF060714),
      drawer: _buildCustomDrawer(context),
      body: Stack(children: [
        Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
          colors: [Color(0xFF060714), Color(0xFF0d0d2b), Color(0xFF060714)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ))),
        Positioned(
            top: -80,
            right: -60,
            child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent.withOpacity(0.07)))),
        Positioned(
            bottom: 100,
            left: -60,
            child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.purpleAccent.withOpacity(0.06)))),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white, size: 26),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const Spacer(),
              ]),
            ),
            Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.04),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.08)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.35),
                              blurRadius: 30,
                              spreadRadius: 2)
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: Colors.blueAccent, size: 32),
                    ),
                    const SizedBox(height: 16),
                    const Text("Sympy",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Text("Pick a vibe for $_aiName",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontWeight: FontWeight.w500,
                            fontSize: 14)),
                    const SizedBox(height: 32),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(children: [
                        _vibeChip("🤪 Chaotic", "Chaotic"),
                        _vibeChip("🧠 Savage", "Savage"),
                        _vibeChip("🧘 Calm", "Therapist"),
                        _vibeChip("😎 Flirty", "Flirty"),
                      ]),
                    ),
                    const SizedBox(height: 60),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 1.0, end: 1.04).animate(
                            CurvedAnimation(
                                parent: _pulseController,
                                curve: Curves.easeInOut)),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => SympyChatPage(
                                          voice: widget.selectedVoice,
                                          vibe: _selectedVibe,
                                          imagePath: widget.imagePath,
                                        )));
                          },
                          child: Container(
                            width: double.infinity,
                            height: 55,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(colors: [
                                Colors.blueAccent,
                                Colors.purpleAccent
                              ]),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.blueAccent.withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8))
                              ],
                            ),
                            child: const Center(
                                child: Text("Get on Board",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5))),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCustomDrawer(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width,
      backgroundColor: Colors.transparent,
      child: Stack(children: [
        Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
          colors: [Color(0xFF060714), Color(0xFF0d0d2b), Color(0xFF060714)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ))),
        Positioned(
            top: -80,
            left: -60,
            child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent.withOpacity(0.07)))),
        Positioned(
            bottom: 100,
            right: -60,
            child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.purpleAccent.withOpacity(0.06)))),
        SafeArea(
          child: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              final user = authSnapshot.data;
              final String displayName = user?.displayName ?? "";
              final String email = user?.email ?? "";
              final String initial =
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : "?";

              return Column(children: [
                const SizedBox(height: 16),
                Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                        icon: Icon(Icons.close,
                            color: Colors.white.withOpacity(0.5)),
                        onPressed: () => Navigator.pop(context))),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  child: Row(children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2)
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [
                              Colors.blueAccent,
                              Colors.purpleAccent
                            ])),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(0xFF0d0d2b),
                          child: Text(initial,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(displayName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                          Text(email,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                  fontSize: 12)),
                        ])),
                  ]),
                ),

                // ── Live credits card ──────────────────────────────────────
                const _CreditsCard(),

                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  child: Divider(
                      color: Colors.white.withOpacity(0.07), height: 1),
                ),
                _drawerItem(Icons.person_outline, "Profile", () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ProfilePage()));
                }),
                _drawerItem(Icons.settings_outlined, "Settings & Privacy",
                    () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => SettingsPage()));
                }),
                _drawerItem(Icons.info_outline_rounded, "About Sympy", () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => AboutPage()));
                }),
                _drawerItem(Icons.flag_outlined, "Report an issue",
                    () => openGmail(),
                    color: Colors.orangeAccent),
                if (kAdminUids
                    .contains(FirebaseAuth.instance.currentUser?.uid))
                  _drawerItem(
                    Icons.admin_panel_settings_outlined,
                    "Admin Panel",
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminPanelPage()));
                    },
                    color: Colors.amber,
                  ),
              ]);
            },
          ),
        ),
      ]),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap,
      {Color color = Colors.blueAccent}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Icon(Icons.chevron_right,
                color: Colors.white.withOpacity(0.2), size: 18),
          ]),
        ),
      ),
    );
  }

  Widget _vibeChip(String label, String value) {
    final isSelected = _selectedVibe == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedVibe = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(right: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Colors.blueAccent, Colors.purpleAccent])
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.08)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.5),
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.normal)),
      ),
    );
  }
}

// ── _CreditsCard ───────────────────────────────────────────────────────────────
// Shows combined call time: paid credits (Firestore) + one-time free seconds.
// Paid credits:  Firestore users/{uid}.credits — real-time stream
// Free seconds:  Firestore users/{uid}.free_seconds_remaining — one-time signup bonus (180s)
// Formula:       1 credit = 12 seconds (5 credits = 1 minute)
// Updates:       Firestore stream updates instantly when admin tops up.

class _CreditsCard extends StatefulWidget {
  const _CreditsCard();

  @override
  State<_CreditsCard> createState() => _CreditsCardState();
}

class _CreditsCardState extends State<_CreditsCard> {
  int _purchasedCredits = 0;
  int _freeSecondsRemaining = 0;
  bool _loading = true;
  StreamSubscription<int>? _creditsSub;

  static const _baseUrl = "https://web-production-6c359.up.railway.app";

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Real-time stream for purchased Firestore credits
    _creditsSub = CreditService().creditsStream().listen((credits) {
      if (mounted) setState(() => _purchasedCredits = credits);
    });

    // Fetch one-time free seconds remaining from backend
    await _fetchFreeSeconds();

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchFreeSeconds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('sympy_user_id') ?? '';
      if (deviceId.isEmpty) return;

      final response = await http.get(
        Uri.parse("$_baseUrl/call_quota"),
        headers: {
          "X-API-KEY": AppSecrets.appApiKey,
          "X-Device-Id": deviceId,
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _freeSecondsRemaining =
                (data['seconds_remaining'] as num?)?.toInt() ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint('[CreditsCard] _fetchFreeSeconds error: $e');
    }
  }

  @override
  void dispose() {
    _creditsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 5 credits = 60s → 1 credit = 12s
    final purchasedSeconds = _purchasedCredits * 12;
    final totalSeconds = purchasedSeconds + _freeSecondsRemaining;
    final totalMinutes = totalSeconds ~/ 60;
    final leftoverSecs = totalSeconds % 60;

    // Main label
    final String timeLabel;
    if (_loading) {
      timeLabel = "Loading...";
    } else if (totalSeconds <= 0) {
      timeLabel = "No call time left";
    } else if (totalMinutes == 0) {
      timeLabel = "${leftoverSecs}s call time left";
    } else if (leftoverSecs == 0) {
      timeLabel =
          "$totalMinutes min${totalMinutes == 1 ? '' : 's'} call time left";
    } else {
      timeLabel =
          "$totalMinutes min ${leftoverSecs}s call time left";
    }

    // Breakdown sublabel
    final freeMins = _freeSecondsRemaining ~/ 60;
    final freeSecs = _freeSecondsRemaining % 60;
    final freeLabel = freeMins > 0
        ? "${freeMins}m${freeSecs > 0 ? ' ${freeSecs}s' : ''}"
        : "${freeSecs}s";

    final String sublabel;
    if (_purchasedCredits > 0 && _freeSecondsRemaining > 0) {
      sublabel =
          "$_purchasedCredits paid credits + $freeLabel free remaining · Chat free";
    } else if (_purchasedCredits > 0) {
      sublabel =
          "$_purchasedCredits paid credits · 5 credits = 1 min · Chat free";
    } else if (_freeSecondsRemaining > 0) {
      sublabel =
          "$freeLabel free remaining · Top up for more · Chat free";
    } else {
      sublabel = "Free minutes used up · Top up to keep calling · Chat is free";
    }

    final isEmpty = !_loading && totalSeconds <= 0;
    final isLow = !_loading && !isEmpty && totalMinutes < 2;

    final Color accent = isEmpty
        ? Colors.purpleAccent
        : isLow
            ? Colors.amber
            : Colors.blueAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GestureDetector(
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UpgradePage()),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: isEmpty
                ? LinearGradient(colors: [
                    Colors.purpleAccent.withOpacity(0.15),
                    Colors.blueAccent.withOpacity(0.1),
                  ])
                : null,
            color: isEmpty ? null : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent
                  .withOpacity(isEmpty || isLow ? 0.3 : 0.07),
            ),
          ),
          child: Row(children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                isEmpty ? Icons.mic_off_outlined : Icons.mic_outlined,
                color: accent,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),

            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: _loading
                          ? Colors.white.withOpacity(0.4)
                          : isEmpty
                              ? Colors.white
                              : isLow
                                  ? Colors.amber
                                  : Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Top Up button
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7b2ff7), Color(0xFF4776E6)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7b2ff7).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Text(
                "Top Up",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

Future<void> openGmail() async {
  final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'sosatechnologies.support@gmail.com',
      query:
          'subject=App Issue Report&body=Please describe the issue here...');
  if (!await launchUrl(emailUri, mode: LaunchMode.externalApplication)) {
    throw 'Could not open email app';
  }
}