import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  // Latest fix: Internal helper to ensure the OS handles the redirect correctly
  Future<void> _launch(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      // mode: LaunchMode.externalApplication ensures it opens in the browser/store app
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Error launching $urlString: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "About Sympy",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity, // Ensures gradient covers full screen
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent.withOpacity(0.1), Colors.black],
          ),
        ),
        // ✅ Added SingleChildScrollView to prevent bottom overlap/overflow
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 140), // Space for AppBar

              // --- APP LOGO SECTION ---
              const Icon(Icons.auto_awesome,
                  color: Colors.blueAccent, size: 80),
              const SizedBox(height: 15),
              const Text(
                "Sympy",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const Text(
                "Version 1.0.0",
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),

              const SizedBox(height: 40),

              // --- MISSION CARD ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: const Column(
                  children: [
                    Text(
                      "Our Mission",
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Sympy is designed to be your intelligent emotional companion. Using advanced AI, we aim to provide a safe space for expression, creativity, and connection whenever you need it.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // --- LINKS CARD ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    _aboutLinkTile(Icons.language, "Website", "www.sympy.ai"),
                    const Divider(
                        color: Colors.white10,
                        height: 1,
                        indent: 20,
                        endIndent: 20),
                    _aboutLinkTile(
                        Icons.description_outlined, "Terms of Service", ""),
                    const Divider(
                        color: Colors.white10,
                        height: 1,
                        indent: 20,
                        endIndent: 20),
                    _aboutLinkTile(Icons.star_outline, "Rate Us", ""),
                  ],
                ),
              ),

              const SizedBox(
                  height: 60), // Fixed padding at bottom instead of Spacer

              const Text(
                "© 2026 Sympy AI Inc.",
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
              const SizedBox(height: 40), // Safety margin for system nav bars
            ],
          ),
        ),
      ),
    );
  }

  Widget _aboutLinkTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent, size: 22),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 16)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (subtitle.isNotEmpty)
            Text(subtitle,
                style: const TextStyle(color: Colors.white24, fontSize: 14)),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
        ],
      ),
      onTap: () {
        // Latest fix integrated: Redirect logic
        if (title == "Website") {
          _launch("https://www.sympy.ai");
        } else if (title == "Terms of Service") {
          _launch("https://www.sympy.ai/terms");
        } else if (title == "Rate Us") {
          // Replace 'your.package.name' with your actual package name from pubspec
          _launch(
              "https://play.google.com/store/apps/details?id=com.sympy.app");
        }
      },
    );
  }
}
