import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // ── Replace these with your actual hosted URLs ──────────────────────────
  static const String _privacyUrl  = "https://www.sympy-ai.info/privacy.html";
  static const String _supportUrl  = "https://www.sympy-ai.info/support.html";
  static const String _reportUrl   = "https://www.sympy-ai.info/report.html";
  static const String _emailUrl    = "mailto:sosatechnologies.support@gmail.com";
  // ────────────────────────────────────────────────────────────────────────

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060714),
      body: Stack(
        children: [
          // ── Background gradient ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF060714), Color(0xFF0d0d2b), Color(0xFF060714)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // ── Glow orbs ──
          Positioned(
            top: -80, right: -80,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: 60, left: -60,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purpleAccent.withOpacity(0.06),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── App bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left,
                            color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            "Settings & Privacy",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [

                      // ── App identity card ──
                      Container(
                        margin: const EdgeInsets.only(bottom: 24, top: 8),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blueAccent.withOpacity(0.15),
                              Colors.purpleAccent.withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.blueAccent.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4776E6),
                                    Color(0xFF8E54E9),
                                  ],
                                ),
                              ),
                              child: const Icon(Icons.auto_awesome,
                                  color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Sympy AI",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "Your Nigerian AI Bestie",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "By Sosa Technologies · v1.0.0",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.25),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── LEGAL section ──
                      _sectionLabel("LEGAL"),
                      _settingsTile(
                        icon: Icons.privacy_tip_outlined,
                        iconColor: Colors.blueAccent,
                        title: "Privacy Policy",
                        subtitle: "How we handle your data",
                        onTap: () => _launch(_privacyUrl),
                      ),

                      // ── HELP section ──
                      _sectionLabel("HELP"),
                      _settingsTile(
                        icon: Icons.help_outline_rounded,
                        iconColor: Colors.purpleAccent,
                        title: "Support & FAQ",
                        subtitle: "Common questions answered",
                        onTap: () => _launch(_supportUrl),
                      ),
                      _settingsTile(
                        icon: Icons.bug_report_outlined,
                        iconColor: const Color(0xFFff4d6d),
                        title: "Report an Issue",
                        subtitle: "Something broken? Tell us",
                        onTap: () => _launch(_reportUrl),
                      ),
                      _settingsTile(
                        icon: Icons.mail_outline_rounded,
                        iconColor: const Color(0xFF22c55e),
                        title: "Contact Us",
                        subtitle: "sosatechnologies.support@gmail.com",
                        onTap: () => _launch(_emailUrl),
                        showExternalIcon: false,
                      ),

                      // ── ABOUT section ──
                      _sectionLabel("ABOUT"),
                      _settingsTile(
                        icon: Icons.info_outline_rounded,
                        iconColor: Colors.white54,
                        title: "App Version",
                        subtitle: "v1.1.0 (Build 1)",
                        onTap: null,
                        showExternalIcon: false,
                        showChevron: false,
                      ),

                      const SizedBox(height: 32),

                      // ── Footer ──
                      Center(
                        child: Column(
                          children: [
                            Text(
                              "Made with immense❤️ in Nigeria",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.2),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "© 2026 Sosa Technologies",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.15),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 20),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool showExternalIcon = true,
    bool showChevron = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: iconColor, size: 19),
            ),
            const SizedBox(width: 14),

            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Right icon
            if (showExternalIcon)
              Icon(Icons.open_in_new,
                  color: Colors.white.withOpacity(0.2), size: 16)
            else if (showChevron)
              Icon(Icons.chevron_right,
                  color: Colors.white.withOpacity(0.15), size: 20),
          ],
        ),
      ),
    );
  }
}
