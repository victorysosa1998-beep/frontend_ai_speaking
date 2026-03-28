import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:loveable/login_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _confirmDelete(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0d0d2b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.08))),
        title: const Text("Delete Account?", style: TextStyle(color: Colors.white)),
        content: Text("This will permanently delete your profile and chat history from our servers. This action cannot be undone.",
          style: TextStyle(color: Colors.white.withOpacity(0.6))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: Colors.white.withOpacity(0.5)))),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseAuth.instance.currentUser?.delete();
                if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please log in again to delete account.")));
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
    final String initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : "?";

    return Scaffold(
      backgroundColor: const Color(0xFF060714),
      body: Stack(children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFF060714), Color(0xFF0d0d2b), Color(0xFF060714)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ))),
        Positioned(top: -60, right: -60, child: Container(width: 240, height: 240,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent.withOpacity(0.07)))),
        Positioned(bottom: 120, left: -50, child: Container(width: 200, height: 200,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purpleAccent.withOpacity(0.06)))),
        SafeArea(
          child: Column(children: [
            // AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
                const Expanded(child: Center(child: Text("Account", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)))),
                const SizedBox(width: 48),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [
                  const SizedBox(height: 20),
                  // Avatar
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 30, spreadRadius: 4),
                        BoxShadow(color: Colors.purpleAccent.withOpacity(0.2), blurRadius: 50, spreadRadius: 8),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent])),
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: const Color(0xFF0d0d2b),
                        child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text("Tap to change profile picture", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
                  const SizedBox(height: 32),
                  // Info card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(children: [
                      _buildInfoRow("Name", displayName, showArrow: true),
                      Divider(color: Colors.white.withOpacity(0.07), height: 1, indent: 20, endIndent: 20),
                      _buildInfoRow("Email", email, showArrow: false),
                      Divider(color: Colors.white.withOpacity(0.07), height: 1, indent: 20, endIndent: 20),
                      ListTile(
                        leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                        title: const Text("Delete Account", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        subtitle: Text("Permanently remove your data", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
                        onTap: () => _confirmDelete(context),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 32),
                  // Logout
                  GestureDetector(
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LoginPage()), (Route<dynamic> route) => false);
                      }
                    },
                    child: Container(
                      width: double.infinity, height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.redAccent.withOpacity(0.08),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
                      ),
                      child: const Center(child: Text("Log out", style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold))),
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

  Widget _buildInfoRow(String label, String value, {required bool showArrow}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
        if (showArrow) ...[const SizedBox(width: 8), Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.2), size: 20)],
      ]),
    );
  }
}