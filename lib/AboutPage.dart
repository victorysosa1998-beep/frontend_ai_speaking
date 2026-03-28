import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _launch(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try { await launchUrl(url, mode: LaunchMode.externalApplication); } catch (e) { debugPrint("Error launching $urlString: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060714),
      body: Stack(children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFF060714), Color(0xFF0d0d2b), Color(0xFF060714)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ))),
        Positioned(top: -80, right: -60, child: Container(width: 280, height: 280,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent.withOpacity(0.07)))),
        Positioned(bottom: 80, left: -50, child: Container(width: 220, height: 220,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purpleAccent.withOpacity(0.06)))),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
                const Expanded(child: Center(child: Text("About Sympy", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)))),
                const SizedBox(width: 48),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const SizedBox(height: 16),
                  // Logo
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                      boxShadow: [
                        BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 40, spreadRadius: 4),
                        BoxShadow(color: Colors.purpleAccent.withOpacity(0.25), blurRadius: 60, spreadRadius: 8),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 48),
                  ),
                  const SizedBox(height: 18),
                  const Text("Sympy", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Text("Version 1.1.0", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13)),
                  const SizedBox(height: 32),
                  // Mission card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.07)),
                    ),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.flag_outlined, color: Colors.blueAccent, size: 18),
                        const SizedBox(width: 8),
                        const Text("Our Mission", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                      ]),
                      const SizedBox(height: 14),
                      Text(
                        "Sympy is designed to be your intelligent emotional companion. Using advanced AI, we aim to provide a safe space for expression, creativity, and connection whenever you need it.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14, height: 1.7),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  // Links card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.07)),
                    ),
                    child: Column(children: [
                      _linkTile(Icons.language, "Website", "www.sympy-ai.info.html", () => _launch("https://www.sympy-ai.info/index.html")),
                      Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 20, endIndent: 20),
                      _linkTile(Icons.description_outlined, "Terms of Service", "", () => _launch("https://www.sympy-ai.info/terms.html")),
                      Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 20, endIndent: 20),
                      _linkTile(Icons.star_outline, "Rate Us", "", () => _launch("https://play.google.com/store/apps/details?id=com.sympy.app")),
                    ]),
                  ),
                  const SizedBox(height: 40),
                  Text("© 2026 Sympy AI Inc.", style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12)),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _linkTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.blueAccent, size: 18),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12)),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.2), size: 20),
      ]),
      onTap: onTap,
    );
  }
}