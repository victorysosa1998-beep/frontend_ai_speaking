import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:loveable/AboutPage.dart';
import 'package:loveable/profilePage.dart';
import 'package:loveable/secrets.dart';
import 'package:loveable/settings_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'SympyChatPage.dart';

class MoodSelectionScreen extends StatefulWidget {
  final String imagePath;
  final String selectedImagePath;
  final String selectedVoice; // ✅ "male" or "female" — passed from voice selection

  const MoodSelectionScreen({
    super.key,
    required this.imagePath,
    required this.selectedImagePath,
    required this.selectedVoice,
  });

  @override
  State<MoodSelectionScreen> createState() => _MoodSelectionScreenState();
}

class _MoodSelectionScreenState extends State<MoodSelectionScreen>
    with TickerProviderStateMixin {
  String _selectedVibe = "Chaotic";
  late AnimationController _pulseController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ✅ Derive AI name from voice — always correct, never hardcoded
  String get _aiName => widget.selectedVoice == "male" ? "Buddy" : "Missy";

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
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
      backgroundColor: const Color(0xFF0F0F0F),
      drawer: _buildCustomDrawer(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.blueAccent, size: 28),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent.withOpacity(0.1), Colors.black],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 50),
            const SizedBox(height: 10),
            const Text(
              "Sympy",
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Pick a vibe for $_aiName",
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _vibeChip("🤪 Chaotic", "Chaotic"),
                  _vibeChip("🧠 Savage", "Savage"),
                  _vibeChip("🧘 Calm", "Therapist"),
                  _vibeChip("😎 Flirty", "Flirty"),
                ],
              ),
            ),
            const SizedBox(height: 80),
            ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.05).animate(
                CurvedAnimation(
                  parent: _pulseController,
                  curve: Curves.easeInOut,
                ),
              ),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SympyChatPage(
                        // ✅ Pass the actual selected voice — never hardcode "female"
                        voice: widget.selectedVoice,
                        vibe: _selectedVibe,
                        imagePath: widget.imagePath,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Colors.blueAccent,
                        Colors.purpleAccent,
                        Colors.blueAccent,
                      ],
                    ),
                  ),
                  child: const Text(
                    "Get on Board",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomDrawer(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width,
      backgroundColor: Colors.black,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent.withOpacity(0.15), Colors.black],
          ),
        ),
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            final user = authSnapshot.data;
            final String displayName = user?.displayName ?? "";
            final String email = user?.email ?? "";
            final String initial =
                displayName.isNotEmpty ? displayName[0].toLowerCase() : "?";

            return Column(
              children: [
                const SizedBox(height: 50),
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // User info
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.green.withOpacity(0.15),
                        child: Text(
                          initial,
                          style: const TextStyle(
                              color: Colors.green,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              email,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Plan row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Free",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text("Upgrade",
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                _drawerItem(Icons.person_outline, "Profile", () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ProfilePage()));
                }),
                _drawerItem(Icons.settings, "Setting & Privacy", () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => SettingsPage()));
                }),
                _drawerItem(Icons.info_outline_rounded, "About Sympy", () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => AboutPage()));
                }),
                _drawerItem(
                  Icons.report,
                  "Report an issue",
                  () => openGmail(),
                  color: Colors.blueAccent,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap,
      {Color color = Colors.blueAccent}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(icon, color: color, size: 26),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500)),
      onTap: onTap,
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
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.white12,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
          ),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

Future<void> openGmail() async {
  final Uri emailUri = Uri(
    scheme: 'mailto',
    path: 'support@Sympyapp.com',
    query: 'subject=App Issue Report&body=Please describe the issue here...',
  );
  if (!await launchUrl(emailUri, mode: LaunchMode.externalApplication)) {
    throw 'Could not open email app';
  }
}