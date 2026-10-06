import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:ovie/secrets.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key});

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  bool _deleting = false;

  Future<void> _openUrl(String value) async {
    if (value.isEmpty) return;
    await launchUrl(Uri.parse(value), mode: LaunchMode.externalApplication);
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _deleting = true);
    try {
      final idToken = await user.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Could not authenticate this deletion request.');
      }

      final response = await http.delete(
        Uri.parse('https://web-production-6c359.up.railway.app/account'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'X-API-KEY': AppSecrets.appApiKey,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('The server could not complete the deletion.');
      }

      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account deletion could not be completed. ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  void _confirmDeletion() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0d0d2b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete your account?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This permanently removes your Ovie account data, credits record and server-side AI memory. This cannot be undone.',
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: _deleting
                ? null
                : () {
                    Navigator.pop(dialogContext);
                    _deleteAccount();
                  },
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPrivacy = AppSecrets.privacyPolicyUrl.isNotEmpty;
    final hasWebDeletion = AppSecrets.accountDeletionUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF060714),
      appBar: AppBar(
        title: const Text('Data & Privacy'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF17245E), Color(0xFF3A165F)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: Colors.white, size: 34),
                SizedBox(height: 14),
                Text(
                  'You are in control.',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 8),
                Text(
                  'You can delete your Ovie account and server-side AI memory at any time.',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (hasPrivacy)
            ListTile(
              tileColor: Colors.white.withOpacity(.045),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: const Icon(Icons.policy_outlined, color: Colors.blueAccent),
              title: const Text('Privacy Policy', style: TextStyle(color: Colors.white)),
              subtitle: const Text('How Ovie handles your data', style: TextStyle(color: Colors.white54)),
              onTap: () => _openUrl(AppSecrets.privacyPolicyUrl),
            ),
          if (hasWebDeletion)
            ListTile(
              tileColor: Colors.white.withOpacity(.045),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: const Icon(Icons.language_rounded, color: Colors.amber),
              title: const Text('Web deletion form', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Use the public deletion page if you cannot sign in', style: TextStyle(color: Colors.white54)),
              onTap: () => _openUrl(AppSecrets.accountDeletionUrl),
            ),
          const SizedBox(height: 24),
          const Text(
            'Permanent deletion',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use the button below while signed in. Ovie verifies your Firebase account before deleting server-side data.',
            style: TextStyle(color: Colors.white54, height: 1.45),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _deleting ? null : _confirmDeletion,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(.15),
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: _deleting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_forever_rounded),
            label: Text(_deleting ? 'Deleting…' : 'Delete my Ovie account'),
          ),
        ],
      ),
    );
  }
}
