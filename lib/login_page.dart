import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import 'voice_selection_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack(
        message: "Please enter email and password",
        icon: Icons.warning_amber_rounded,
        color: Colors.orangeAccent,
      );
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      UserCredential cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // Reload to get the freshest user state from Firebase
      await cred.user?.reload();
      final User? user = FirebaseAuth.instance.currentUser;

      // Guard: if user is somehow null after sign-in, stop spinner and bail
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        _showSnack(
          message: "Login failed. Please try again.",
          icon: Icons.error_outline,
          color: Colors.redAccent,
        );
        return;
      }

      // ── EMAIL VERIFICATION CHECK ─────────────────────────────────
      // Remove or comment out the block below if you do NOT require
      // email verification in your app — it will cause a spinner hang
      // for any account that was created without verifying email.
      // ─────────────────────────────────────────────────────────────
      // if (!user.emailVerified) {
      //   await FirebaseAuth.instance.signOut();
      //   if (mounted) setState(() => _isLoading = false);
      //   _showSnack(
      //     message: "Please verify your email before logging in.",
      //     icon: Icons.mark_email_unread_outlined,
      //     color: Colors.blueAccent,
      //   );
      //   return;
      // }

      // ✅ Login successful — navigate explicitly.
      // Never rely on the StreamBuilder in MyApp to handle post-login
      // navigation. The StreamBuilder controls MyApp's root home widget,
      // but LoginPage is pushed on top of the Navigator stack, so any
      // StreamBuilder rebuild underneath never reaches this screen.
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const VoiceSelectionScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _isLoading = false);
      String message = "Login failed. Please try again.";
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-credential':
          message = "No account found with this email.";
          break;
        case 'wrong-password':
          message = "Incorrect password.";
          break;
        case 'invalid-email':
          message = "Please enter a valid email address.";
          break;
        case 'network-request-failed':
          message = "Network error. Check your connection.";
          break;
        case 'too-many-requests':
          message = "Too many attempts. Try again later.";
          break;
        case 'user-disabled':
          message = "This account has been disabled.";
          break;
        case 'network-request-failed':
          message = "No internet connection. Please check your network.";
          break;
      }
      _showSnack(
          message: message,
          icon: Icons.error_outline,
          color: Colors.redAccent);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Login error: $e");
      final msg = e.toString().contains('network') || e.toString().contains('socket')
          ? "No internet connection. Please check your network."
          : "Something went wrong. Please try again.";
      _showSnack(message: msg, icon: Icons.error_outline, color: Colors.redAccent);
    } finally {
      // Safety net — guarantees spinner ALWAYS stops even if an edge case
      // slips through both try and catch blocks
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack({
    required String message,
    required IconData icon,
    required Color color,
  }) {
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
        ]),
      ),
    ));
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.3), fontSize: 15),
          prefixIcon:
              Icon(icon, color: Colors.white.withOpacity(0.3), size: 20),
          suffixIcon: onToggle != null
              ? IconButton(
                  onPressed: onToggle,
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white.withOpacity(0.3),
                    size: 20,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060714),
      body: Stack(children: [
        Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
          colors: [
            Color(0xFF060714),
            Color(0xFF0d0d2b),
            Color(0xFF060714)
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ))),
        Positioned(
            top: -80,
            left: -80,
            child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent.withOpacity(0.07)))),
        Positioned(
            bottom: 100,
            right: -60,
            child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.purpleAccent.withOpacity(0.06)))),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.04),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.35),
                          blurRadius: 35,
                          spreadRadius: 2)
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.blueAccent, size: 36),
                ),
                const SizedBox(height: 22),
                const Text("Welcome Back",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text("Sign in to continue",
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 14)),
                const SizedBox(height: 36),
                _inputField(
                    controller: _emailController,
                    hint: "Email",
                    icon: Icons.email_outlined),
                const SizedBox(height: 14),
                _inputField(
                    controller: _passwordController,
                    hint: "Password",
                    icon: Icons.lock_outline,
                    obscure: _obscurePassword,
                    onToggle: () => setState(
                        () => _obscurePassword = !_obscurePassword)),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ForgotPasswordPage())),
                    child: Text("Forgot Password?",
                        style: TextStyle(
                            color: Colors.blueAccent.withOpacity(0.8),
                            fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _isLoading ? null : _login,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: _isLoading
                          ? null
                          : const LinearGradient(
                              colors: [
                                Colors.blueAccent,
                                Colors.purpleAccent
                              ],
                            ),
                      color: _isLoading
                          ? Colors.white.withOpacity(0.07)
                          : null,
                      boxShadow: _isLoading
                          ? []
                          : [
                              BoxShadow(
                                  color:
                                      Colors.blueAccent.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8))
                            ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : const Text("Login",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                      child: Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.07))),
                  Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      child: Text("or",
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 13))),
                  Expanded(
                      child: Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.07))),
                ]),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SignupPage())),
                  child: Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withOpacity(0.05),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Center(
                        child: Text(
                      "Don't have an account? Sign Up",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500),
                    )),
                  ),
                ),
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}