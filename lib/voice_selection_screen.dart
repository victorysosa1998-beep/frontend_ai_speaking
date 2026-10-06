import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'mood_selection_screen.dart';
import 'app_brand.dart';
import 'ovie_ui.dart';

class VoiceSelectionScreen extends StatefulWidget {
  const VoiceSelectionScreen({super.key});
  @override
  State<VoiceSelectionScreen> createState() => _VoiceSelectionScreenState();
}

class _VoiceSelectionScreenState extends State<VoiceSelectionScreen> {
  String? _selectedVoice;
  String? _selectedImagePath;

  void _selectVoice(String voice, String imagePath) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedVoice = voice;
      _selectedImagePath = imagePath;
    });
  }

  void _next() {
    if (_selectedVoice == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Please choose Buddy or Missy first!"),
        backgroundColor: OvieBrand.primary,
        duration: Duration(seconds: 2),
      ));
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => MoodSelectionScreen(
          selectedVoice: _selectedVoice!,
          imagePath: _selectedImagePath!,
          selectedImagePath: _selectedImagePath!,
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OvieBrand.background,
      body: OvieBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.04),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                            boxShadow: [
                              BoxShadow(
                                color: OvieBrand.primary.withOpacity(0.35),
                                blurRadius: 35,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const OvieLogo(size: 60, showWordmark: false),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          "Choose your companion",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Pick a voice that feels like you. Meet Ovie first, then choose your vibe.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 36),
                        Row(
                          children: [
                            Expanded(
                              child: _genderCard(
                                name: "Buddy",
                                subtitle: "Chill & playful",
                                voice: "male",
                                assetPath: 'assets/images/buddy.png',
                                accentColor: const Color(0xFF4A90D9),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _genderCard(
                                name: "Missy",
                                subtitle: "Warm & lively",
                                voice: "female",
                                assetPath: 'assets/images/missy.png',
                                accentColor: const Color(0xFFBD5175),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: OvieGradientButton(
                  label: "NEXT",
                  icon: Icons.arrow_forward_rounded,
                  active: _selectedVoice != null,
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _genderCard({
    required String name,
    required String subtitle,
    required String voice,
    required String assetPath,
    required Color accentColor,
  }) {
    final bool isSelected = _selectedVoice == voice;
    return GestureDetector(
      onTap: () => _selectVoice(voice, assetPath),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
        transform: Matrix4.identity()..scale(isSelected ? 1.03 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(0.14)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isSelected ? accentColor : Colors.white.withOpacity(0.08),
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: accentColor.withOpacity(0.32), blurRadius: 24, spreadRadius: 1)]
              : const [],
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: EdgeInsets.all(isSelected ? 3 : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? LinearGradient(colors: [accentColor, accentColor.withOpacity(0.4)])
                        : null,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      assetPath,
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => CircleAvatar(
                        radius: 42,
                        backgroundColor: accentColor.withOpacity(0.2),
                        child: Icon(
                          voice == "male" ? Icons.person : Icons.person_2,
                          color: accentColor,
                          size: 42,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: AnimatedScale(
                    scale: isSelected ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: OvieBrand.background, width: 2),
                      ),
                      child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.65),
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? accentColor : Colors.white.withOpacity(0.3),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
