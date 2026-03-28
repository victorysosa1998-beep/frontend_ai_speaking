import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'mood_selection_screen.dart';

class VoiceSelectionScreen extends StatefulWidget {
  const VoiceSelectionScreen({super.key});
  @override
  State<VoiceSelectionScreen> createState() => _VoiceSelectionScreenState();
}

class _VoiceSelectionScreenState extends State<VoiceSelectionScreen> with TickerProviderStateMixin {
  String? _selectedVoice;
  String? _selectedImagePath;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  }

  @override
  void dispose() { _pulseController.dispose(); super.dispose(); }

  void _selectVoice(String voice, String imagePath) {
    HapticFeedback.mediumImpact();
    setState(() { _selectedVoice = voice; _selectedImagePath = imagePath; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060714),
      body: Stack(children: [
        // Background gradient
        Container(decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFF060714), Color(0xFF0d0d2b), Color(0xFF060714)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ))),
        // Glow blobs
        Positioned(top: -80, left: -60, child: Container(width: 300, height: 300,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent.withOpacity(0.07)))),
        Positioned(bottom: 100, right: -60, child: Container(width: 240, height: 240,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purpleAccent.withOpacity(0.06)))),
        SafeArea(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Spacer(),
            // Logo
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 35, spreadRadius: 2)],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 36),
            ),
            const SizedBox(height: 20),
            const Text("Sympy", style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text("Meet your companion!", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 48),
            // Cards
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _genderCard(name: "Buddy", voice: "male", assetPath: 'assets/images/buddy.png', accentColor: const Color(0xFF4A90D9)),
              const SizedBox(width: 16),
              _genderCard(name: "Missy", voice: "female", assetPath: 'assets/images/missy.png', accentColor: const Color(0xFFBD5175)),
            ]),
            const Spacer(),
            // NEXT button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.04).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                child: GestureDetector(
                  onTap: _selectedVoice == null
                    ? () {
                        HapticFeedback.heavyImpact();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Please choose Buddy or Missy first!"),
                          backgroundColor: Colors.blueAccent,
                          duration: Duration(seconds: 2),
                        ));
                      }
                    : () {
                        HapticFeedback.lightImpact();
                        Navigator.push(context, PageRouteBuilder(
                          pageBuilder: (_, __, ___) => MoodSelectionScreen(
                            selectedVoice: _selectedVoice!,
                            imagePath: _selectedImagePath!,
                            selectedImagePath: _selectedImagePath!,
                          ),
                          transitionsBuilder: (_, animation, __, child) => SlideTransition(
                            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
                            child: child,
                          ),
                        ));
                      },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity, height: 55,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: _selectedVoice != null
                        ? const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent])
                        : null,
                      color: _selectedVoice == null ? Colors.white.withOpacity(0.07) : null,
                      boxShadow: _selectedVoice != null
                        ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))]
                        : [],
                      border: _selectedVoice == null ? Border.all(color: Colors.white.withOpacity(0.08)) : null,
                    ),
                    child: Center(child: Text("NEXT",
                      style: TextStyle(
                        color: _selectedVoice != null ? Colors.white : Colors.white.withOpacity(0.3),
                        fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5,
                      ))),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ]),
    );
  }

  Widget _genderCard({required String name, required String voice, required String assetPath, required Color accentColor}) {
    final bool isSelected = _selectedVoice == voice;
    return GestureDetector(
      onTap: () => _selectVoice(voice, assetPath),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 150,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.12) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? accentColor : Colors.white.withOpacity(0.08), width: isSelected ? 1.5 : 1),
          boxShadow: isSelected ? [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)] : [],
        ),
        child: Column(children: [
          // Avatar with glow
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: isSelected ? [BoxShadow(color: accentColor.withOpacity(0.5), blurRadius: 20, spreadRadius: 3)] : [],
            ),
            child: Container(
              padding: EdgeInsets.all(isSelected ? 2.5 : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected ? LinearGradient(colors: [accentColor, accentColor.withOpacity(0.5)]) : null,
              ),
              child: ClipOval(
                child: Image.asset(assetPath, width: 80, height: 80, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => CircleAvatar(
                    radius: 40, backgroundColor: accentColor.withOpacity(0.2),
                    child: Icon(voice == "male" ? Icons.person : Icons.person_2, color: accentColor, size: 40),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(name, style: TextStyle(color: isSelected ? Colors.white : Colors.white.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(voice == "male" ? "Male" : "Female",
            style: TextStyle(color: isSelected ? accentColor : Colors.white.withOpacity(0.25), fontSize: 12)),
        ]),
      ),
    );
  }
}