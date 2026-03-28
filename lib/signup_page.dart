import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'otp_verification_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnack("Please fill all fields", Colors.orangeAccent);
      return;
    }
    setState(() => _isLoading = true);
    try {
      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      await cred.user?.updateDisplayName(name);
      await cred.user?.sendEmailVerification();
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OtpVerificationPage(email: email, isPasswordReset: false)));
      }
    } on FirebaseAuthException catch (e) {
      String message = "Signup failed. Please try again.";
      switch (e.code) {
        case 'email-already-in-use':
          message = "An account already exists with this email.";
          break;
        case 'invalid-email':
          message = "Please enter a valid email address.";
          break;
        case 'weak-password':
          message = "Password is too weak. Use at least 6 characters.";
          break;
        case 'network-request-failed':
          message = "No internet connection. Please check your network.";
          break;
        case 'too-many-requests':
          message = "Too many attempts. Please try again later.";
          break;
        case 'operation-not-allowed':
          message = "Signup is currently unavailable. Try again later.";
          break;
      }
      _showSnack(message, Colors.redAccent);
    } catch (e) {
      _showSnack("No internet connection. Please check your network.", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    final icon = color == Colors.redAccent
        ? Icons.error_outline
        : color == Colors.orangeAccent
            ? Icons.warning_amber_rounded
            : Icons.check_circle_outline;
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
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
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
        Positioned(top: -60, right: -60, child: Container(width: 260, height: 260,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purpleAccent.withOpacity(0.07)))),
        Positioned(bottom: 80, left: -50, child: Container(width: 200, height: 200,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent.withOpacity(0.06)))),
        SafeArea(
          child: Column(children: [
            // Back button
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(children: [
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                      boxShadow: [BoxShadow(color: Colors.purpleAccent.withOpacity(0.35), blurRadius: 35, spreadRadius: 2)],
                    ),
                    child: const Icon(Icons.person_add_outlined, color: Colors.purpleAccent, size: 36),
                  ),
                  const SizedBox(height: 20),
                  const Text("Create Account", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text("Join Sympy today", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
                  const SizedBox(height: 36),
                  _inputField(controller: _nameController, hint: "Full Name", icon: Icons.badge_outlined),
                  const SizedBox(height: 14),
                  _inputField(controller: _emailController, hint: "Email", icon: Icons.email_outlined),
                  const SizedBox(height: 14),
                  _inputField(controller: _passwordController, hint: "Password", icon: Icons.lock_outline, obscure: true),
                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: _isLoading ? null : _signup,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity, height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: _isLoading ? null : const LinearGradient(colors: [Colors.purpleAccent, Colors.blueAccent]),
                        color: _isLoading ? Colors.white.withOpacity(0.07) : null,
                        boxShadow: _isLoading ? [] : [BoxShadow(color: Colors.purpleAccent.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: Center(child: _isLoading
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text("Sign Up", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
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

  Widget _inputField({required TextEditingController controller, required String hint, required IconData icon, bool obscure = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller, obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 15),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.3), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}