import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'app_brand.dart';
import 'ovie_ui.dart';

class RingingCallScreen extends StatefulWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final String callerName;

  const RingingCallScreen({
    super.key,
    required this.onAccept,
    required this.onDecline,
    required this.callerName,
  });

  @override
  State<RingingCallScreen> createState() => _RingingCallScreenState();
}

class _RingingCallScreenState extends State<RingingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _handleIncomingCall();
  }

  // ---- ringing / vibration logic (unchanged) ----
  Future<void> _handleIncomingCall() async {
    await Future.delayed(const Duration(milliseconds: 800));
    RingerModeStatus ringerStatus;
    try {
      ringerStatus = await SoundMode.ringerModeStatus;
    } catch (e) {
      ringerStatus = RingerModeStatus.normal;
    }
    if (ringerStatus == RingerModeStatus.normal) {
      _startVibration();
      _startRinging();
    } else if (ringerStatus == RingerModeStatus.vibrate) {
      _startVibration();
    }
  }

  void _startVibration() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 1000, 500, 1000], repeat: 0);
    }
  }

  void _startRinging() {
    FlutterRingtonePlayer().play(
      android: AndroidSounds.ringtone,
      ios: IosSounds.glass,
      looping: true,
      volume: 1.0,
      asAlarm: false,
    );
  }

  void _stopActions() {
    FlutterRingtonePlayer().stop();
    Vibration.cancel();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stopActions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OvieBrand.background,
      body: OvieBackground(
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              _incomingBadge(),
              const SizedBox(height: 36),
              _pulsingAvatar(),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  widget.callerName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _ringingDots(),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _actionButton(
                      label: "Decline",
                      icon: Icons.call_end_rounded,
                      colors: const [Color(0xFFFF5252), Color(0xFFC62828)],
                      glow: Colors.redAccent,
                      onTap: () {
                        _stopActions();
                        widget.onDecline();
                      },
                    ),
                    _actionButton(
                      label: "Accept",
                      icon: Icons.call_rounded,
                      colors: const [Color(0xFF00E676), Color(0xFF00A152)],
                      glow: Colors.greenAccent,
                      onTap: () {
                        _stopActions();
                        widget.onAccept();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 56),
            ],
          ),
        ),
      ),
    );
  }

  Widget _incomingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0xFF4CAF50)),
          ),
          const SizedBox(width: 8),
          Text(
            "Incoming call",
            style: TextStyle(
                color: Colors.white.withOpacity(0.6), fontSize: 13, letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }

  Widget _pulsingAvatar() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        final v = _pulseController.value;
        return SizedBox(
          width: 230,
          height: 230,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _ring(205 + 22 * v, OvieBrand.primary.withOpacity(0.08 + 0.10 * v)),
              _ring(170 + 12 * v, OvieBrand.secondary.withOpacity(0.12 + 0.12 * v)),
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: OvieBrand.primary.withOpacity(0.30 + 0.20 * v),
                      blurRadius: 44 + 20 * v,
                      spreadRadius: 4 + 4 * v,
                    ),
                  ],
                ),
              ),
              Container(
                width: 128,
                height: 128,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: OvieBrand.royalGradient,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: OvieBrand.surface),
                  child: Icon(Icons.person_rounded,
                      size: 62, color: Colors.white.withOpacity(0.7)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ring(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
    );
  }

  Widget _ringingDots() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Ringing",
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45), fontSize: 15, letterSpacing: 0.5)),
          const SizedBox(width: 2),
          ...List.generate(3, (i) {
            final threshold = (i + 1) / 3;
            final visible = _pulseController.value >= threshold - 0.33;
            return AnimatedOpacity(
              opacity: visible ? 0.8 : 0.15,
              duration: const Duration(milliseconds: 200),
              child: Text(".",
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 20)),
            );
          }),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required List<Color> colors,
    required Color glow,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: glow.withOpacity(0.45),
                  blurRadius: 26,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 12),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.5), fontSize: 13, letterSpacing: 0.5)),
      ],
    );
  }
}
