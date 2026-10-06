import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ovie/login_page.dart';
import 'app_brand.dart';
import 'ovie_ui.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _confirmDelete(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: OvieBrand.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text("Delete Account?", style: TextStyle(color: Colors.white)),
        content: Text(
          "This will permanently delete your profile and chat history from our servers. This action cannot be undone.",
          style: TextStyle(color: Colors.white.withOpacity(0.6), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Cancel", style: TextStyle(color: Colors.white.withOpacity(0.55))),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseAuth.instance.currentUser?.delete();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              } catch (e) {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please log in again to delete account.")),
                  );
                }
              }
            },
            child: const Text("Delete",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
      backgroundColor: OvieBrand.background,
      body: OvieBackground(
        child: SafeArea(
          child: Column(
            children: [
              const OvieHeader(title: "Account"),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: OvieBrand.primary.withOpacity(0.40),
                              blurRadius: 34,
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
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: OvieBrand.surface,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        displayName.isNotEmpty ? displayName : "Ovie user",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 32),
                      OvieGlassCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _buildInfoRow(Icons.person_outline_rounded, "Name",
                                displayName.isEmpty ? "—" : displayName),
                            _divider(),
                            _buildInfoRow(Icons.mail_outline_rounded, "Email",
                                email.isEmpty ? "—" : email),
                            _divider(),
                            ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              leading: const Icon(Icons.delete_forever_rounded,
                                  color: Colors.redAccent),
                              title: const Text("Delete Account",
                                  style: TextStyle(
                                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
                              subtitle: Text("Permanently remove your data",
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.35), fontSize: 12)),
                              onTap: () => _confirmDelete(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            backgroundColor: Colors.redAccent.withOpacity(0.08),
                            side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                          ),
                          icon: const Icon(Icons.logout_rounded, size: 20),
                          label: const Text("Log out",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (context) => const LoginPage()),
                                (Route<dynamic> route) => false,
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => Divider(
        color: Colors.white.withOpacity(0.07),
        height: 1,
        indent: 20,
        endIndent: 20,
      );

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Icon(icon, color: OvieBrand.secondary, size: 20),
          const SizedBox(width: 14),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
