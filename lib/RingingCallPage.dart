import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

class RingingCallScreen extends StatefulWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final String callerName;

  const RingingCallScreen({super.key, required this.onAccept, required this.onDecline, required this.callerName});

  @override
  State<RingingCallScreen> createState() => _RingingCallScreenState();
}

class _RingingCallScreenState extends State<RingingCallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _handleIncomingCall();
  }

  Future<void> _handleIncomingCall() async {
    await Future.delayed(const Duration(milliseconds: 800));
    RingerModeStatus ringerStatus;
    try { ringerStatus = await SoundMode.ringerModeStatus; } catch (e) { ringerStatus = RingerModeStatus.normal; }
    if (ringerStatus == RingerModeStatus.normal) { _startVibration(); _startRinging(); }
    else if (ringerStatus == RingerModeStatus.vibrate) { _startVibration(); }
  }

  void _startVibration() async {
    if (await Vibration.hasVibrator() ?? false) Vibration.vibrate(pattern: [0, 1000, 500, 1000], repeat: 0);
  }

  void _startRinging() {
    FlutterRingtonePlayer().play(android: AndroidSounds.ringtone, ios: IosSounds.glass, looping: true, volume: 1.0, asAlarm: false);
  }

  void _stopActions() { FlutterRingtonePlayer().stop(); Vibration.cancel(); }

  @override
  void dispose() { _pulseController.dispose(); _stopActions(); super.dispose(); }

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
        // Ambient blobs
        Positioned(top: -100, left: -80, child: Container(width: 350, height: 350,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent.withOpacity(0.08)))),
        Positioned(bottom: 60, right: -80, child: Container(width: 280, height: 280,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purpleAccent.withOpacity(0.07)))),
        Positioned(top: 200, right: -40, child: Container(width: 160, height: 160,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent.withOpacity(0.04)))),
        SafeArea(
          child: Column(children: [
            const Spacer(),
            // ── CALLER INFO ──────────────────────────────────────────
            // Incoming badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4CAF50))),
                const SizedBox(width: 7),
                Text("Incoming call", style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13, letterSpacing: 0.6)),
              ]),
            ),
            const SizedBox(height: 36),
            // Pulsing rings + avatar
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, child) {
                final v = _pulseController.value;
                return SizedBox(
                  width: 220, height: 220,
                  child: Stack(alignment: Alignment.center, children: [
                    // Outer ring
                    Container(
                      width: 200 + 20 * v, height: 200 + 20 * v,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.08 + 0.08 * v), width: 1.5),
                      ),
                    ),
                    // Mid ring
                    Container(
                      width: 165 + 10 * v, height: 165 + 10 * v,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.12 + 0.10 * v), width: 1.5),
                      ),
                    ),
                    // Glow
                    Container(
                      width: 132, height: 132,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.blueAccent.withOpacity(0.28 + 0.18 * v), blurRadius: 40 + 20 * v, spreadRadius: 4 + 4 * v),
                          BoxShadow(color: Colors.purpleAccent.withOpacity(0.15 * v), blurRadius: 60, spreadRadius: 6),
                        ],
                      ),
                    ),
                    // Avatar
                    Container(
                      width: 128, height: 128,
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.blueAccent, Colors.purpleAccent],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0d0d2b)),
                        child: Icon(Icons.person_rounded, size: 62, color: Colors.white.withOpacity(0.65)),
                      ),
                    ),
                  ]),
                );
              },
            ),
            const SizedBox(height: 30),
            // Caller name
            Text(
              widget.callerName,
              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            // Animated dots
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
                Text("Ringing", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 15, letterSpacing: 0.5)),
                const SizedBox(width: 2),
                ...List.generate(3, (i) {
                  final threshold = (i + 1) / 3;
                  final visible = _pulseController.value >= threshold - 0.33;
                  return AnimatedOpacity(
                    opacity: visible ? 0.7 : 0.15,
                    duration: const Duration(milliseconds: 200),
                    child: Text(".", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 20)),
                  );
                }),
              ]),
            ),
            const Spacer(),
            // ── CONTROLS ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                // Decline
                Column(children: [
                  GestureDetector(
                    onTap: () { _stopActions(); widget.onDecline(); },
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [Color(0xFFff4444), Color(0xFFcc0000)]),
                        boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 24, spreadRadius: 2, offset: const Offset(0, 6))],
                      ),
                      child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text("Decline", style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12, letterSpacing: 0.5)),
                ]),
                // Swipe hint line between buttons
                Container(width: 60, height: 1, color: Colors.white.withOpacity(0.06)),
                // Accept
                Column(children: [
                  GestureDetector(
                    onTap: () { _stopActions(); widget.onAccept(); },
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [Color(0xFF00c853), Color(0xFF007a33)]),
                        boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.45), blurRadius: 24, spreadRadius: 2, offset: const Offset(0, 6))],
                      ),
                      child: const Icon(Icons.call_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text("Accept", style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12, letterSpacing: 0.5)),
                ]),
              ]),
            ),
            const SizedBox(height: 56),
          ]),
        ),
      ]),
    );
  }
}