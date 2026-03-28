import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'otp_verification_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendResetCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack(message: "Please enter your email", icon: Icons.warning_amber_rounded, color: Colors.orangeAccent);
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => OtpVerificationPage(email: email, isPasswordReset: true)));
    } on FirebaseAuthException catch (e) {
      String message = "Something went wrong. Please try again.";
      switch (e.code) {
        case 'user-not-found':
          message = "No account found with this email.";
          break;
        case 'invalid-email':
          message = "Please enter a valid email address.";
          break;
        case 'network-request-failed':
          message = "No internet connection. Please check your network.";
          break;
        case 'too-many-requests':
          message = "Too many attempts. Please try again later.";
          break;
      }
      _showSnack(message: message, icon: Icons.error_outline, color: Colors.redAccent);
    } catch (e) {
      _showSnack(message: "No internet connection. Please check your network.", icon: Icons.wifi_off, color: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        Positioned(top: -60, left: -60, child: Container(width: 260, height: 260,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent.withOpacity(0.07)))),
        Positioned(bottom: 100, right: -50, child: Container(width: 200, height: 200,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purpleAccent.withOpacity(0.06)))),
        SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                      boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.35), blurRadius: 35, spreadRadius: 2)],
                    ),
                    child: const Icon(Icons.lock_reset, color: Colors.blueAccent, size: 36),
                  ),
                  const SizedBox(height: 22),
                  const Text("Reset Password", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Text("Enter your email to receive a reset link",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
                  const SizedBox(height: 36),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withOpacity(0.05),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: "Email",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 15),
                        prefixIcon: Icon(Icons.email_outlined, color: Colors.white.withOpacity(0.3), size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: _isLoading ? null : _sendResetCode,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity, height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: _isLoading ? null : const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent]),
                        color: _isLoading ? Colors.white.withOpacity(0.07) : null,
                        boxShadow: _isLoading ? [] : [BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: Center(child: _isLoading
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text("Send Reset Link", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}