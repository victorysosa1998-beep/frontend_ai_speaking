import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountDeletionPage extends StatelessWidget {
  const AccountDeletionPage({super.key});
  final String webDeletionUrl = "https://your-website.com/delete-account";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060714),
      body: Stack(children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFF060714), Color(0xFF0d0d2b), Color(0xFF060714)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ))),
        Positioned(top: -60, right: -60, child: Container(width: 240, height: 240,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent.withOpacity(0.05)))),
        Positioned(bottom: 100, left: -50, child: Container(width: 200, height: 200,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purpleAccent.withOpacity(0.05)))),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
                const Expanded(child: Center(child: Text("Data & Privacy", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)))),
                const SizedBox(width: 48),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.07)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.shield_outlined, color: Colors.blueAccent, size: 20)),
                        const SizedBox(width: 12),
                        const Text("Your Privacy Matters", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 14),
                      Text(
                        "In compliance with Google Play policies, you can request the permanent deletion of your account and all associated AI conversation data.",
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.6),
                      ),
                    ]),
                  ),
                  const Spacer(),
                  Center(
                    child: TextButton(
                      onPressed: () => launchUrl(Uri.parse(webDeletionUrl)),
                      child: Text("Privacy Policy & Web Deletion Form",
                        style: TextStyle(color: Colors.blueAccent.withOpacity(0.7), fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _confirmDeletion(context),
                    child: Container(
                      width: double.infinity, height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.redAccent.withOpacity(0.08),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: const Center(child: Text("Delete Account Immediately",
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15))),
                    ),
                  ),
                  const SizedBox(height: 30),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  void _confirmDeletion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0d0d2b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.08))),
        title: const Text("Delete permanently?", style: TextStyle(color: Colors.white)),
        content: Text("This will erase your AI history and account. This cannot be undone.",
          style: TextStyle(color: Colors.white.withOpacity(0.5))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: Colors.white.withOpacity(0.5)))),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.currentUser?.delete();
              if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
            },
            child: const Text("Confirm Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}