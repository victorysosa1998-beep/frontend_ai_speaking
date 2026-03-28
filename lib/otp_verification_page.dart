import 'package:flutter/material.dart';

class OtpVerificationPage extends StatelessWidget {
  final String email;
  final bool isPasswordReset;

  const OtpVerificationPage({super.key, required this.email, required this.isPasswordReset});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060714),
      body: Stack(children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFF060714), Color(0xFF0d0d2b), Color(0xFF060714)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ))),
        Positioned(top: -80, right: -60, child: Container(width: 280, height: 280,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent.withOpacity(0.07)))),
        Positioned(bottom: 80, left: -50, child: Container(width: 200, height: 200,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purpleAccent.withOpacity(0.06)))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.35), blurRadius: 35, spreadRadius: 2)],
                ),
                child: const Icon(Icons.mark_email_read_outlined, color: Colors.blueAccent, size: 40),
              ),
              const SizedBox(height: 28),
              const Text("Check Your Email", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              Text("We sent a link to", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 15), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.25)),
                ),
                child: Text(email, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.07)),
                ),
                child: Text(
                  "If the email exists with us, click the link in your email to reset your password and continue to login.",
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.6),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
                child: Container(
                  width: double.infinity, height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent]),
                    boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: const Center(child: Text("Back to Login", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}