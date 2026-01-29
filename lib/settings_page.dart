// lib/settings_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        leading: BackButton(color: Colors.white),
        title: const Text("Settings & Privacy",
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("LEGAL",
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: Colors.blueAccent),
            title: const Text("Privacy Policy",
                style: TextStyle(color: Colors.white)),
            trailing:
                const Icon(Icons.open_in_new, color: Colors.white24, size: 20),
            onTap: () => _launchUrl(
                "https://your-website.com/privacy"), // REPLACE WITH YOUR URL
          ),
          const Divider(color: Colors.white12),
          ListTile(
            leading: const Icon(Icons.support, color: Colors.blueAccent),
            title: const Text("Support & FAQ",
                style: TextStyle(color: Colors.white)),
            trailing:
                const Icon(Icons.open_in_new, color: Colors.white24, size: 20),
            onTap: () => _launchUrl(
                "https://your-website.com/terms"), // REPLACE WITH YOUR URL
          ),
          const Divider(color: Colors.white12),
          ListTile(
            leading: const Icon(Icons.report, color: Colors.blueAccent),
            title: const Text("Report an issue",
                style: TextStyle(color: Colors.white)),
            trailing:
                const Icon(Icons.open_in_new, color: Colors.white24, size: 20),
            onTap: () => _launchUrl(
                "https://your-website.com/terms"), // REPLACE WITH YOUR URL
          ),
          const Divider(color: Colors.white12),
        ],
      ),
    );
  }
}
