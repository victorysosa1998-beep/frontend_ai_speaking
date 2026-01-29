import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountDeletionPage extends StatelessWidget {
  const AccountDeletionPage({super.key});

  final String webDeletionUrl = "https://your-website.com/delete-account";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(title: const Text("Data & Privacy"), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Your Privacy Matters", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              "In compliance with Google Play policies, you can request the permanent deletion of your account and all associated AI conversation data.",
              style: TextStyle(color: Colors.white70),
            ),
            const Spacer(),
            Center(
              child: TextButton(
                onPressed: () => launchUrl(Uri.parse(webDeletionUrl)),
                child: const Text("Privacy Policy & Web Deletion Form"),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1), foregroundColor: Colors.red),
                onPressed: () => _confirmDeletion(context),
                child: const Text("Delete Account Immediately"),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _confirmDeletion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete permanently?"),
        content: const Text("This will erase your AI history and account. This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.currentUser?.delete();
              if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
            }, 
            child: const Text("Confirm Delete", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }
}