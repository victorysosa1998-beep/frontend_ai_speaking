import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'SympyChatPage.dart';

class MoodSelectionScreen extends StatefulWidget {
  final String selectedVoice;
  final String imagePath; 
  const MoodSelectionScreen({super.key, required this.selectedVoice, required this.imagePath});
  @override
  State<MoodSelectionScreen> createState() => _MoodSelectionScreenState();
}

class _MoodSelectionScreenState extends State<MoodSelectionScreen>
    with TickerProviderStateMixin {
  String _selectedVibe = "Chaotic";
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
              "Choose your AI vibe",
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 30),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _vibeChip("🤪 Chaotic", "Chaotic"),
                  _vibeChip("🧠 Savage", "Savage"),
                  _vibeChip("🧘 Calm", "Therapist"),
                  _vibeChip("😎 Flirty", "Flirty"),
                ],
              ),
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
                    MaterialPageRoute(
                      builder: (_) => SympyChatPage(
                        voice: widget.selectedVoice,
                        vibe: _selectedVibe,
                        imagePath: widget.imagePath,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    gradient: LinearGradient(
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
                    "Get on Board",
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

  Widget _vibeChip(String label, String value) {
    final isSelected = _selectedVibe == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedVibe = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.white12,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
          ),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}