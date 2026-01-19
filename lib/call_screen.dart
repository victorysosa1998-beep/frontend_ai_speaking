import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class CallScreen extends StatefulWidget {
  final String voice;
  final String vibe;
  const CallScreen({super.key, required this.voice, required this.vibe});
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  double _userLevel = 0;
  double _aiLevel = 0;
  Timer? _statsTimer;
  Timer? _durationTimer;
  int _seconds = 0;
  String _lastTranscript = "Connecting to sympy...";
  bool _exited = false;
  String? _activeEmoji;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      final res = await http
          .get(
            Uri.parse(
              "http://192.168.60.157:8000/get_token?gender=${widget.voice}&vibe=${widget.vibe}",
            ),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);
      final String token = data["token"];

      _room = Room();
      _listener = _room!.createListener();

      _listener!
        ..on<TrackSubscribedEvent>((event) async {
          if (event.track is RemoteAudioTrack) {
            await event.track.start();
            await _room!.setSpeakerOn(true);
          }
        })
        ..on<AudioPlaybackStatusChanged>((event) async {
          if (!_room!.canPlaybackAudio) await _room!.startAudio();
        })
        ..on<DataReceivedEvent>((event) {
          final text = utf8.decode(event.data);
          if (!mounted) return;

          if (text.startsWith("REACTION|")) {
            setState(() => _activeEmoji = text.split("|")[1]);
            Timer(const Duration(seconds: 2), () {
              if (mounted) setState(() => _activeEmoji = null);
            });
            return;
          }

          setState(() {
            if (event.topic == "transcript:ai") {
              _lastTranscript = "AI: $text";
            } else if (event.topic == "transcript:user") {
              _lastTranscript = "You: $text";
            } else {
              _lastTranscript = text;
            }
          });
        })
        ..on<RoomDisconnectedEvent>((event) => _safeExit());

      await _room!.connect("wss://key-5d1ldsh2.livekit.cloud", token);
      await _room!.startAudio();
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      await _room!.setSpeakerOn(true);

      _startTimers();
      if (!mounted) return;
      setState(() {
        _isConnected = true;
        _lastTranscript = "Listening...";
      });
    } catch (e) {
      if (mounted) _safeExit();
    }
  }

  void _startTimers() {
    _statsTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_room == null || !mounted) return;
      setState(() {
        _userLevel = _room!.localParticipant?.audioLevel ?? 0;
        final remote = _room!.remoteParticipants.values.isNotEmpty
            ? _room!.remoteParticipants.values.first
            : null;
        _aiLevel = remote?.audioLevel ?? 0;
      });
    });
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  void _safeExit() {
    if (_exited) return;
    _exited = true;
    _statsTimer?.cancel();
    _durationTimer?.cancel();
    _listener?.dispose();
    _room?.disconnect();
    if (mounted) Navigator.pop(context);
  }

  String _time() =>
      "${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}";

  @override
  void dispose() {
    _safeExit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  _isConnected ? _time() : "Connecting...",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontFamily: 'monospace',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 20,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      _lastTranscript,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  widget.voice == "male" ? "Brother AI" : "Sister AI",
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Vibe: ${widget.vibe}",
                  style: const TextStyle(color: Colors.white24, fontSize: 14),
                ),
                const SizedBox(height: 30),
                WaveWidget(level: _aiLevel, color: Colors.blueAccent),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Icon(Icons.compare_arrows, color: Colors.white10),
                ),
                WaveWidget(
                  level: _isMuted ? 0 : _userLevel,
                  color: Colors.greenAccent,
                ),
                const SizedBox(height: 20),
                Text(
                  _isMuted ? "MIC MUTED" : "YOU ARE SPEAKING",
                  style: TextStyle(
                    color: _isMuted ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _circle(Icons.mic, !_isMuted, () async {
                        setState(() => _isMuted = !_isMuted);
                        await _room!.localParticipant?.setMicrophoneEnabled(
                          !_isMuted,
                        );
                      }),
                      _circle(Icons.call_end, false, _safeExit, red: true),
                      _circle(Icons.volume_up, _isSpeakerOn, () async {
                        setState(() => _isSpeakerOn = !_isSpeakerOn);
                        await _room!.setSpeakerOn(_isSpeakerOn);
                      }),
                    ],
                  ),
                ),
              ],
            ),
            if (_activeEmoji != null)
              Center(
                child: TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, val, child) => Transform.scale(
                    scale: val * 1.5,
                    child: Opacity(
                      opacity: (val * 1.5).clamp(0, 1),
                      child: Text(
                        _activeEmoji!,
                        style: const TextStyle(fontSize: 120),
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

  Widget _circle(
    IconData icon,
    bool active,
    VoidCallback onTap, {
    bool red = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: red
              ? Colors.red
              : (active ? Colors.white12 : Colors.red.withOpacity(0.2)),
          border: Border.all(color: red ? Colors.transparent : Colors.white10),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

class WaveWidget extends StatelessWidget {
  final double level;
  final Color color;
  const WaveWidget({super.key, required this.level, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(13, (i) {
        final h = 8 + (level * 120 * (1 - (i - 6).abs() / 7));
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 6,
          height: h.clamp(8.0, 100.0),
          decoration: BoxDecoration(
            color: color.withOpacity((h / 100).clamp(0.3, 1.0)),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}