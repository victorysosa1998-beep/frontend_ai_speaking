import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'mood_selection_screen.dart';
import 'secrets.dart';

class VoiceSelectionScreen extends StatefulWidget {
  const VoiceSelectionScreen({super.key});
  @override
  State<VoiceSelectionScreen> createState() => _VoiceSelectionScreenState();
}

class _VoiceSelectionScreenState extends State<VoiceSelectionScreen>
    with TickerProviderStateMixin {
  final String _selectedVoice = "female";
  final String _selectedImagePath = 'assets/images/missy.png';

  late AnimationController _pulseController;
 
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }


  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      backgroundColor: const Color(0xFF0F0F0F),
    
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent.withOpacity(0.1), Colors.black],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 50),
            const SizedBox(height: 10),
            const Text(
              "Sympy",
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              "Meet your companion! ",
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _genderCard(
                  "Missy",
                  "female",
                  'assets/images/missy.png',
                  const Color.fromARGB(255, 189, 81, 117),
                ),
              ],
            ),
            const SizedBox(height: 80),
            ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.05).animate(
                CurvedAnimation(
                  parent: _pulseController,
                  curve: Curves.easeInOut,
                ),
              ),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => MoodSelectionScreen(
                        selectedVoice: _selectedVoice,
                        imagePath: _selectedImagePath,
                        selectedImagePath: 'assets/images/missy.png',
                      ),
                      transitionsBuilder: (_, animation, __, child) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        );
                      },
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 86, vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Colors.blueAccent,
                        Colors.purpleAccent,
                        Colors.blueAccent,
                      ],
                    ),
                  ),
                  child: const Text(
                    "NEXT",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _genderCard(
      String name, String gender, String assetPath, Color borderColor) {
    bool isSelected = true;
    return GestureDetector(
      onTap: () => HapticFeedback.mediumImpact(),
      child:
          _partnerCardImage(name, gender, assetPath, borderColor, isSelected),
    );
  }

  Widget _partnerCardImage(String name, String value, String assetPath,
      Color borderColor, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blueAccent.withOpacity(0.15)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
            color: isSelected ? borderColor : Colors.transparent, width: 2),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: isSelected ? borderColor : Colors.transparent,
                  width: 3),
            ),
            child: ClipOval(
              child: Image.asset(assetPath,
                  width: 60, height: 60, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            name,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.white24,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
