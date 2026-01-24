import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'voice_selection_screen.dart';

// 1. Initial Entry Point

// ----------------- NEW WELCOME SCREEN -----------------
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _welcomeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _welcomeController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 2000,
      ), // Time for the total animation
    );

    _fadeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(begin: 0.0, end: 1.0),
            weight: 40,
          ), // Fade In
          TweenSequenceItem(tween: ConstantTween(1.0), weight: 20), // Stay
          TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 0.0),
            weight: 40,
          ), // Fade Out slowly
        ]).animate(
          CurvedAnimation(parent: _welcomeController, curve: Curves.easeInOut),
        );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.05).animate(
      CurvedAnimation(parent: _welcomeController, curve: Curves.easeOutCubic),
    );

    _welcomeController.forward();

    // Navigate to SplashScreen after the Welcome animation finishes
    Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 1000),
            pageBuilder: (context, anim, secondAnim) => const SplashScreen(),
            transitionsBuilder: (context, anim, secondAnim, child) {
              return FadeTransition(opacity: anim, child: child);
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _welcomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "WELCOME",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 42,
                    fontWeight: FontWeight.w300, // Elegant thin font
                    letterSpacing: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 50,
                  height: 1,
                  color: Colors.blueAccent.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------- YOUR ORIGINAL SPLASH SCREEN (UNTOUCHED) -----------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacityAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const VoiceSelectionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.blueAccent.withOpacity(0.1),
                  Colors.transparent,
                ],
                radius: 1.5,
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _opacityAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.2),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.blueAccent,
                      size: 80,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 35),
              const Text(
                "sympy",
                style: TextStyle(
                  color: Color.fromARGB(255, 255, 255, 255),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Connecting you to your AI vibe",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const Positioned(
            bottom: 50,
            child: SizedBox(
              width: 40,
              height: 40,
              child: CupertinoActivityIndicator(
                radius: 20.0,
                color: Colors.blueAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}