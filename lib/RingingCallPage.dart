import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

class RingingCallScreen extends StatefulWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  final String callerName; 

  const RingingCallScreen({
    super.key, 
    required this.onAccept, 
    required this.onDecline, 
    required this.callerName, // This was missing from your constructor
  });

  @override
  State<RingingCallScreen> createState() => _RingingCallScreenState();
}

class _RingingCallScreenState extends State<RingingCallScreen> {
  @override
  void initState() {
    super.initState();
    _handleIncomingCall();
  }

  Future<void> _handleIncomingCall() async {
    // 800ms delay to ensure Android handles audio focus correctly
    await Future.delayed(const Duration(milliseconds: 800));

    // Check if phone is on Silent, Vibrate, or Ringing
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
    _stopActions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const CircleAvatar(
              radius: 55,
              backgroundColor: Colors.white10,
              child: Icon(Icons.person, size: 65, color: Colors.white),
            ),
            const SizedBox(height: 25),
            // We access callerName using "widget.callerName"
            Text(
              widget.callerName, 
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 36, 
                fontWeight: FontWeight.bold
              ),
            ),
            const Text(
              "Incoming Call", 
              style: TextStyle(color: Colors.white54, fontSize: 18, letterSpacing: 1.2)
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _actionBtn(Icons.call_end, Colors.red, () {
                    _stopActions();
                    widget.onDecline();
                  }),
                  _actionBtn(Icons.call, Colors.green, () {
                    _stopActions();
                    widget.onAccept();
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onPress) {
    return SizedBox(
      width: 70,
      height: 70,
      child: FloatingActionButton(
        heroTag: null,
        backgroundColor: color,
        onPressed: onPress,
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}