import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'mood_selection_screen.dart';

class VoiceSelectionScreen extends StatefulWidget {
  const VoiceSelectionScreen({super.key});
  @override
  State<VoiceSelectionScreen> createState() => _VoiceSelectionScreenState();
}

class _VoiceSelectionScreenState extends State<VoiceSelectionScreen>
    with TickerProviderStateMixin {
  // ✅ Start with no selection — user must actively choose
  String? _selectedVoice;
  String? _selectedImagePath;

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

  void _selectVoice(String voice, String imagePath) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedVoice = voice;
      _selectedImagePath = imagePath;
    });
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
              "Meet your companion!",
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 50),
            // ✅ Both Buddy and Missy side by side
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _genderCard(
                  name: "Buddy",
                  voice: "male",
                  assetPath: 'assets/images/buddy.png',
                  borderColor: const Color(0xFF4A90D9),
                ),
                const SizedBox(width: 20),
                _genderCard(
                  name: "Missy",
                  voice: "female",
                  assetPath: 'assets/images/missy.png',
                  borderColor: const Color.fromARGB(255, 189, 81, 117),
                ),
              ],
            ),
            const SizedBox(height: 80),
            // ✅ NEXT button — only active when a voice is selected
            ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.05).animate(
                CurvedAnimation(
                  parent: _pulseController,
                  curve: Curves.easeInOut,
                ),
              ),
              child: GestureDetector(
                onTap: _selectedVoice == null
                    ? () {
                        HapticFeedback.heavyImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please choose Buddy or Missy first!"),
                            backgroundColor: Colors.blueAccent,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    : () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => MoodSelectionScreen(
                              selectedVoice: _selectedVoice!,
                              imagePath: _selectedImagePath!,
                              selectedImagePath: _selectedImagePath!,
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 86, vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    gradient: _selectedVoice != null
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              Colors.blueAccent,
                              Colors.purpleAccent,
                              Colors.blueAccent,
                            ],
                          )
                        : null,
                    color: _selectedVoice == null
                        ? Colors.white12
                        : null,
                  ),
                  child: Text(
                    "NEXT",
                    style: TextStyle(
                      color: _selectedVoice != null
                          ? Colors.white
                          : Colors.white38,
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

  Widget _genderCard({
    required String name,
    required String voice,
    required String assetPath,
    required Color borderColor,
  }) {
    final bool isSelected = _selectedVoice == voice;
    return GestureDetector(
      onTap: () => _selectVoice(voice, assetPath),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withOpacity(0.15)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? borderColor : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? borderColor : Colors.transparent,
                  width: 3,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  assetPath,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  // Fallback if asset not found
                  errorBuilder: (_, __, ___) => CircleAvatar(
                    radius: 40,
                    backgroundColor: borderColor.withOpacity(0.3),
                    child: Icon(
                      voice == "male" ? Icons.person : Icons.person_2,
                      color: borderColor,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              voice == "male" ? "Male" : "Female",
              style: TextStyle(
                color: isSelected ? borderColor : Colors.white24,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}