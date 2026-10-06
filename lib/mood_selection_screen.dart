import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ovie/AboutPage.dart';
import 'package:ovie/profilePage.dart';
import 'package:ovie/secrets.dart';
import 'package:ovie/settings_page.dart';
import 'package:ovie/Creditservice.dart';
import 'package:ovie/UpgradePage.dart';
import 'package:ovie/Adminpanelpage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'OvieChatPage.dart';
import 'fun_zone.dart';
import 'group_call_page.dart';
import 'app_brand.dart';
import 'ovie_ui.dart';

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
      backgroundColor: OvieBrand.background,
      drawer: _buildCustomDrawer(context),
      body: OvieBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(children: [
                OvieIconButton(
                  icon: Icons.menu_rounded,
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const Spacer(),
                OvieIconButton(
                  icon: Icons.auto_awesome_rounded,
                  color: OvieBrand.royalGold,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FunZonePage()),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Chosen companion
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: OvieBrand.primary.withOpacity(0.4),
                              blurRadius: 36,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: OvieBrand.royalGradient,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              widget.imagePath,
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const OvieLogo(
                                  size: 96, showWordmark: false),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(_aiName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3)),
                      const SizedBox(height: 6),
                      Text("How should $_aiName feel today?",
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontWeight: FontWeight.w500,
                              fontSize: 15)),
                      const SizedBox(height: 28),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 12,
                        children: [
                          _vibeChip("🤪 Chaotic", "Chaotic"),
                          _vibeChip("🔥 Savage", "Savage"),
                          _vibeChip("🧘 Calm", "Therapist"),
                          _vibeChip("⚡ Hype", "Hype"),
                          _vibeChip("🗣️ Gist", "Gist"),
                          _vibeChip("📖 Story", "Story"),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.03).animate(
                    CurvedAnimation(
                        parent: _pulseController, curve: Curves.easeInOut)),
                child: OvieGradientButton(
                  label: "START THE VIBE",
                  icon: Icons.bolt_rounded,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => OvieChatPage(
                                  voice: widget.selectedVoice,
                                  vibe: _selectedVibe,
                                  imagePath: widget.imagePath,
                                )));
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupCallPage(
                        voice: widget.selectedVoice,
                        vibe: _selectedVibe,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.groups_rounded),
                  label: const Text('Play with friends',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withOpacity(.04),
                    side: BorderSide(color: Colors.white.withOpacity(.16)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildCustomDrawer(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width,
      backgroundColor: Colors.transparent,
      child: OvieBackground(
        child: SafeArea(
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
                _drawerItem(Icons.auto_awesome_rounded, "Ovie Fun Zone", () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FunZonePage()));
                }, color: Colors.amberAccent),
                _drawerItem(Icons.person_outline, "Profile", () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ProfilePage()));
                }),
                _drawerItem(Icons.settings_outlined, "Settings & Privacy",
                    () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => SettingsPage()));
                }),
                _drawerItem(Icons.info_outline_rounded, "About Ovie", () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => AboutPage()));
                }),
                _drawerItem(Icons.flag_outlined, "Report an issue",
                    () => openGmail(),
                    color: Colors.orangeAccent),
                FutureBuilder<bool>(
                  future: checkIsAdmin(),
                  builder: (context, snapshot) {
                    if (snapshot.data != true) return const SizedBox.shrink();
                    return _drawerItem(
                      Icons.admin_panel_settings_outlined,
                      "Admin Panel",
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminPanelPage(),
                          ),
                        );
                      },
                      color: Colors.amber,
                    );
                  },
                ),
              ]);
            },
          ),
        ),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? OvieBrand.royalGradient : null,
          color: isSelected ? null : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.1)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: OvieBrand.primary.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 5))
                ]
              : const [],
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 15,
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500)),
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
        ? OvieBrand.primary
        : isLow
            ? Colors.amber
            : OvieBrand.secondary;

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
                    OvieBrand.primary.withOpacity(0.15),
                    OvieBrand.secondary.withOpacity(0.1),
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
                  colors: [Color(0xFF8B5CF6), Color(0xFF4F8CFF)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: OvieBrand.primary.withOpacity(0.3),
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