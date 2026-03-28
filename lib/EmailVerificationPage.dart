import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';

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
  void dispose() { _timer?.cancel(); super.dispose(); }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldown == 0) { timer.cancel(); } else { setState(() => _cooldown--); }
    });
  }

  Future<void> _resendVerificationEmail() async {
    if (_cooldown > 0) return;
    setState(() => _isSending = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) { _showSnack(message: "User not found. Please log in again.", icon: Icons.error_outline, color: Colors.redAccent); return; }
      await user.reload();
      user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        _showSnack(message: "Email already verified! You can log in now.", icon: Icons.check_circle_outline, color: Colors.greenAccent);
        return;
      }
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        _showSnack(message: "Verification email sent! Check your inbox.", icon: Icons.mark_email_read_outlined, color: Colors.greenAccent);
        _startCooldown();
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Something went wrong. Please try again.";
      switch (e.code) {
        case 'too-many-requests':
          msg = "Too many attempts. Please wait a minute.";
          break;
        case 'user-not-found':
          msg = "Session expired. Please log in again.";
          break;
        case 'network-request-failed':
          msg = "No internet connection. Please check your network.";
          break;
        case 'invalid-user-token':
        case 'user-token-expired':
          msg = "Session expired. Please log in again.";
          break;
      }
      _showSnack(message: msg, icon: Icons.warning_amber_outlined, color: Colors.orangeAccent);
    } catch (e) {
      _showSnack(message: "No internet connection. Please check your network.", icon: Icons.wifi_off, color: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSnack({required String message, required IconData icon, required Color color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      duration: const Duration(seconds: 3),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0d0d2b),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 6)),
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12),
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
        ]),
      ),
    ));
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
        Positioned(top: -80, left: -60, child: Container(width: 280, height: 280,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent.withOpacity(0.07)))),
        Positioned(bottom: 80, right: -50, child: Container(width: 200, height: 200,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purpleAccent.withOpacity(0.06)))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.35), blurRadius: 35, spreadRadius: 2)],
                ),
                child: const Icon(Icons.verified_outlined, color: Colors.blueAccent, size: 40),
              ),
              const SizedBox(height: 28),
              const Text("Verify Your Email", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text("We sent a verification link to", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 15), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.25)),
                ),
                child: Text(widget.email, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.07)),
                ),
                child: Text("Click the link in your email to verify your account before logging in.",
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.6), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _isSending || _cooldown > 0 ? null : _resendVerificationEmail,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity, height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: (_isSending || _cooldown > 0) ? null : const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent]),
                    color: (_isSending || _cooldown > 0) ? Colors.white.withOpacity(0.07) : null,
                    boxShadow: (_isSending || _cooldown > 0) ? [] : [BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Center(child: _isSending
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(_cooldown > 0 ? "Resend in $_cooldown s" : "Resend Verification Link",
                        style: TextStyle(color: _cooldown > 0 ? Colors.white38 : Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false),
                child: Container(
                  width: double.infinity, height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Center(child: Text("Back to Login", style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500, fontSize: 15))),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}