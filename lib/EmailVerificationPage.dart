import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart'; // Your actual LoginPage

class EmailVerificationPage extends StatefulWidget {
  final String email;

  const EmailVerificationPage({super.key, required this.email});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _isSending = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _cooldown = 60; // 60s cooldown
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldown == 0) {
        timer.cancel();
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _resendVerificationEmail() async {
    if (_cooldown > 0) return;

    setState(() => _isSending = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showSnack(
          message: "User not found. Please log in again.",
          icon: Icons.error_outline,
          color: Colors.redAccent,
        );
        return;
      }

      // Refresh user to get latest emailVerified status
      await user.reload();
      user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        _showSnack(
          message: "Email already verified! You can log in now.",
          icon: Icons.check_circle_outline,
          color: Colors.greenAccent,
        );
        return;
      }

      // Send verification email safely
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        _showSnack(
          message: "Verification email sent! Check your inbox.",
          icon: Icons.mark_email_read_outlined,
          color: Colors.greenAccent,
        );
        _startCooldown();
      }
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? "Something went wrong";
      if (e.code == 'too-many-requests') {
        msg = "Too many requests. Please wait a minute.";
      } else if (e.code == 'user-not-found') {
        msg = "User not found. Log in again.";
      }
      _showSnack(
        message: msg,
        icon: Icons.warning_amber_outlined,
        color: Colors.orangeAccent,
      );
    } catch (e) {
      _showSnack(
        message: "Error: $e",
        icon: Icons.error_outline,
        color: Colors.redAccent,
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSnack({
    required String message,
    required IconData icon,
    required Color color,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Verify Your Email",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              "We sent a verification link to",
              style: TextStyle(color: Colors.white38, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              widget.email,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            const Text(
              "Click the link in your email to verify your account before logging in.",
              style: TextStyle(color: Colors.white38, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _isSending || _cooldown > 0
                    ? null
                    : _resendVerificationEmail,
                child: _isSending
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text(
                        _cooldown > 0
                            ? "Resend in $_cooldown s"
                            : "Resend Verification Link",
                        style: const TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () {
                  // Always go back to actual LoginPage
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                },
                child: const Text(
                  "Back to Login",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
