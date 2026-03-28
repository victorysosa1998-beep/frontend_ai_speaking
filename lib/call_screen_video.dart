// import 'package:flutter/material.dart';
// import 'package:livekit_client/livekit_client.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'dart:async';
// import 'dart:math' as math;
// import 'dart:typed_data';
// import 'package:camera/camera.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'secrets.dart';

// // ─────────────────────────────────────────────────────────────────────────────
// // CallScreen — realistic video call with animated avatar + camera PiP + AI vision
// // ─────────────────────────────────────────────────────────────────────────────

// class VideoCallScreen extends StatefulWidget {
//   final String voice;
//   final String vibe;
//   final String imagePath;
//   const VideoCallScreen({
//     super.key,
//     required this.voice,
//     required this.vibe,
//     required this.imagePath,
//   });
//   @override
//   State<VideoCallScreen> createState() => _VideoCallScreenState();
// }

// class _VideoCallScreenState extends State<VideoCallScreen>
//     with TickerProviderStateMixin {

//   // ── LiveKit ──────────────────────────────────────────────────────────────
//   Room? _room;
//   EventsListener<RoomEvent>? _listener;
//   bool _isConnected = false;
//   bool _isMuted = false;
//   bool _isSpeakerOn = false;
//   double _userLevel = 0;
//   double _aiLevel = 0;
//   Timer? _statsTimer;
//   Timer? _durationTimer;
//   int _seconds = 0;
//   String _lastTranscript = "Connecting...";
//   bool _exited = false;
//   String? _activeEmoji;
//   bool _hasError = false;

//   // ── Quota ─────────────────────────────────────────────────────────────────
//   String _deviceId = "";
//   int _secondsRemaining = 0;
//   int _dailyLimitSeconds = 300;
//   int _lastSavedSeconds = 0;
//   bool _quotaExhausted = false;

//   // ── Rotating subtitles ────────────────────────────────────────────────────
//   late List<String> _displayTexts;
//   int _textIndex = 0;
//   Timer? _textFadeTimer;

//   // ── Avatar mouth animation ────────────────────────────────────────────────
//   // We simulate a realistic talking mouth using _aiLevel + noise + smoothing.
//   // No extra assets needed — we morph the existing avatar with a CustomPainter.
//   late AnimationController _mouthController;
//   late AnimationController _blinkController;
//   late AnimationController _breathController;
//   double _smoothedAiLevel = 0;          // exponential smoothing
//   double _mouthNoise = 0;               // random micro-movement while talking
//   bool _isBlinking = false;
//   Timer? _blinkTimer;
//   Timer? _breathTimer;

//   // ── Camera (user PiP) ─────────────────────────────────────────────────────
//   CameraController? _cameraController;
//   bool _cameraReady = false;
//   bool _cameraEnabled = true;
//   Timer? _visionTimer;                  // sends frames to GPT-4o every 8s
//   String? _aiVisionComment;             // what AI said about what it sees
//   Timer? _visionCommentTimer;

//   // ── Floating PiP drag ─────────────────────────────────────────────────────
//   Offset? _pipOffset; // initialized on first build using screen size
//   bool _pipExpanded = false;

//   @override
//   void initState() {
//     super.initState();

//     final aiName = widget.voice == "male" ? "Buddy" : "Missy";
//     _displayTexts = [
//       aiName,
//       "Cooking up some major vibes... 🍳",
//       "Checking the street for update... 🤫",
//       "Abeg hold on, I dey find words... 🧐",
//       "Vibe check in progress... 🔋",
//       "Sharpening my tongue... 🔪",
//     ];

//     // Mouth animation controller — drives the CustomPainter mouth overlay
//     _mouthController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 80),
//     );

//     // Blink controller — natural eye blink every 3-6 seconds
//     _blinkController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 120),
//     );

//     // Breathing controller — subtle scale pulse (life-like)
//     _breathController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 3500),
//     )..repeat(reverse: true);

//     _startTextRotation();
//     _startBlinkLoop();
//     _loadDeviceIdThenConnect();
//     _initCamera();
//   }

//   // ── Text rotation ─────────────────────────────────────────────────────────
//   void _startTextRotation() {
//     _textFadeTimer = Timer.periodic(const Duration(seconds: 3), (_) {
//       if (mounted) setState(() => _textIndex = (_textIndex + 1) % _displayTexts.length);
//     });
//   }

//   // ── Natural blinking ──────────────────────────────────────────────────────
//   void _startBlinkLoop() {
//     _scheduleNextBlink();
//   }

//   void _scheduleNextBlink() {
//     final delay = Duration(milliseconds: 2800 + math.Random().nextInt(3200));
//     _blinkTimer = Timer(delay, () async {
//       if (!mounted) return;
//       setState(() => _isBlinking = true);
//       await Future.delayed(const Duration(milliseconds: 120));
//       if (mounted) setState(() => _isBlinking = false);
//       _scheduleNextBlink();
//     });
//   }

//   // ── Camera init ───────────────────────────────────────────────────────────
//   Future<void> _initCamera() async {
//     try {
//       final cameras = await availableCameras();
//       final front = cameras.firstWhere(
//         (c) => c.lensDirection == CameraLensDirection.front,
//         orElse: () => cameras.first,
//       );
//       _cameraController = CameraController(
//         front,
//         ResolutionPreset.medium,
//         enableAudio: false,
//         imageFormatGroup: ImageFormatGroup.jpeg,
//       );
//       await _cameraController!.initialize();
//       if (mounted) setState(() => _cameraReady = true);
//       // Start sending frames to AI every 8 seconds after call connects
//     } catch (e) {
//       debugPrint("[Camera] init failed: $e");
//     }
//   }

//   void _startVisionLoop() {
//     // Wait 3s after connect before first frame so camera is stable
//     Future.delayed(const Duration(seconds: 3), () {
//       _visionTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
//         if (!_isConnected || !_cameraEnabled) return;
//         if (_cameraController == null || !_cameraController!.value.isInitialized) return;
//         if (_cameraController!.value.isTakingPicture) return; // skip if busy
//         try {
//           // captureFrame grabs from the live stream without interrupting preview
//           final xfile = await _cameraController!.takePicture();
//           final bytes = await xfile.readAsBytes();
//           if (bytes.length > 500) {
//             _log("VISION", "Sending frame: ${bytes.length} bytes");
//             _sendFrameToAI(bytes);
//           }
//         } catch (e) {
//           _log("VISION", "Frame capture failed: $e");
//         }
//       });
//     });
//   }

//   Future<void> _sendFrameToAI(Uint8List imageBytes) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final userId = prefs.getString("sympy_user_id") ?? "";
//       if (userId.isEmpty) return;

//       final response = await http.post(
//         Uri.parse("https://web-production-6c359.up.railway.app/call_vision"),
//         headers: {
//           "Content-Type": "application/octet-stream",
//           "X-API-KEY": AppSecrets.appApiKey,
//           "X-User-Id": userId,
//         },
//         body: imageBytes,
//       ).timeout(const Duration(seconds: 12));

//       _log("VISION", "Response: ${response.statusCode}");

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final comment = data["comment"] as String? ?? "";
//         _log("VISION", "Comment: $comment");

//         if (comment.isNotEmpty && mounted) {
//           // Show toast on screen
//           setState(() => _aiVisionComment = comment);
//           _visionCommentTimer?.cancel();
//           _visionCommentTimer = Timer(const Duration(seconds: 6), () {
//             if (mounted) setState(() => _aiVisionComment = null);
//           });

//           // Send comment as a data message into the LiveKit room
//           // so the agent receives it and speaks it out loud
//           if (_room != null && _isConnected) {
//             try {
//               final payload = utf8.encode("VISION_COMMENT|$comment");
//               await _room!.localParticipant?.publishData(
//                 payload,
//                 reliable: true,
//               );
//               _log("VISION", "Sent to agent via data channel");
//             } catch (e) {
//               _log("VISION", "Could not send to agent: $e");
//             }
//           }
//         }
//       } else {
//         _log("VISION", "Error response: ${response.body}");
//       }
//     } catch (e) {
//       _log("VISION", "Send failed: $e");
//     }
//   }

//   void _log(String tag, dynamic msg) => debugPrint("[CallScreen|$tag] $msg");

//   // ── Device ID + Quota ─────────────────────────────────────────────────────
//   Future<void> _loadDeviceIdThenConnect() async {
//     final prefs = await SharedPreferences.getInstance();
//     final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
//     String stored;
//     if (firebaseUid != null) {
//       stored = "user_$firebaseUid";
//       await prefs.setString("sympy_user_id", stored);
//     } else {
//       String? existing = prefs.getString("sympy_user_id");
//       if (existing == null) {
//         final rand = DateTime.now().millisecondsSinceEpoch.toString();
//         existing = "user_${rand.substring(rand.length - 10)}";
//         await prefs.setString("sympy_user_id", existing);
//       }
//       stored = existing;
//     }
//     if (mounted) setState(() => _deviceId = stored);
//     await _flushPendingSeconds(prefs, stored);
//     await _checkQuotaBeforeCall(stored);
//   }

//   Future<void> _flushPendingSeconds(SharedPreferences prefs, String deviceId) async {
//     final pending = prefs.getInt("pending_call_seconds") ?? 0;
//     final pendingDevice = prefs.getString("pending_call_device_id") ?? "";
//     if (pending <= 0 || pendingDevice.isEmpty) return;
//     try {
//       final res = await http.post(
//         Uri.parse("https://web-production-6c359.up.railway.app/call_ended?duration_seconds=$pending"),
//         headers: {"X-API-KEY": AppSecrets.appApiKey, "X-Device-Id": pendingDevice},
//       ).timeout(const Duration(seconds: 8));
//       if (res.statusCode == 200) {
//         await prefs.remove("pending_call_seconds");
//         await prefs.remove("pending_call_device_id");
//       }
//     } catch (_) {}
//   }

//   Future<void> _checkQuotaBeforeCall(String deviceId) async {
//     try {
//       final res = await http.get(
//         Uri.parse("https://web-production-6c359.up.railway.app/call_quota"),
//         headers: {"X-API-KEY": AppSecrets.appApiKey, "X-Device-Id": deviceId},
//       ).timeout(const Duration(seconds: 10));
//       if (res.statusCode == 200) {
//         final data = jsonDecode(res.body);
//         final int remaining = data["seconds_remaining"] ?? 0;
//         final bool canCall = data["can_call"] ?? false;
//         final int limit = data["limit"] ?? 300;
//         if (!canCall || remaining <= 0) {
//           if (mounted) setState(() {
//             _secondsRemaining = 0;
//             _dailyLimitSeconds = limit;
//             _quotaExhausted = true;
//           });
//           return;
//         }
//         if (mounted) setState(() {
//           _secondsRemaining = remaining;
//           _dailyLimitSeconds = limit;
//         });
//       }
//     } catch (_) {
//       if (mounted) setState(() => _secondsRemaining = 300);
//     }
//     _connect();
//   }

//   Future<bool> _reportUsage({bool isFinal = false}) async {
//     if (_deviceId.isEmpty) return false;
//     final delta = _seconds - _lastSavedSeconds;
//     if (delta <= 0) return false;
//     try {
//       final res = await http.post(
//         Uri.parse("https://web-production-6c359.up.railway.app/call_ended?duration_seconds=$delta"),
//         headers: {"X-API-KEY": AppSecrets.appApiKey, "X-Device-Id": _deviceId},
//       ).timeout(Duration(seconds: isFinal ? 8 : 5));
//       if (res.statusCode == 200) {
//         _lastSavedSeconds = _seconds;
//         return true;
//       }
//       return false;
//     } catch (_) { return false; }
//   }

//   Future<bool> _reportCallEnded() => _reportUsage(isFinal: true);

//   // ── Connect ───────────────────────────────────────────────────────────────
//   Future<void> _connect() async {
//     setState(() {
//       _hasError = false;
//       _lastTranscript = "Connecting...";
//     });
//     try {
//       await Future.delayed(const Duration(milliseconds: 800));
//       final url = "https://web-production-6c359.up.railway.app/get_token"
//           "?gender=${widget.voice}&vibe=${widget.vibe}";
//       final res = await http.get(
//         Uri.parse(url),
//         headers: {"X-API-KEY": AppSecrets.appApiKey, "X-Device-Id": _deviceId},
//       ).timeout(const Duration(seconds: 15));

//       if (res.statusCode == 429) {
//         if (mounted) setState(() { _quotaExhausted = true; _secondsRemaining = 0; });
//         return;
//       }
//       if (res.statusCode != 200) throw "API Error: ${res.statusCode}";
//       final data = jsonDecode(res.body);
//       final String token = data["token"];

//       if (data["seconds_remaining"] != null && mounted) {
//         setState(() {
//           _dailyLimitSeconds = data["limit"] ?? _dailyLimitSeconds;
//           _secondsRemaining = (data["seconds_remaining"] as int).clamp(0, _dailyLimitSeconds);
//         });
//       }

//       _room = Room();
//       _listener = _room!.createListener();
//       _listener!
//         ..on<TrackSubscribedEvent>((e) async {
//           if (e.track is RemoteAudioTrack) await e.track.start();
//         })
//         ..on<DataReceivedEvent>((e) {
//           final text = utf8.decode(e.data);
//           if (!mounted) return;
//           if (text.startsWith("REACTION|")) {
//             setState(() => _activeEmoji = text.split("|")[1]);
//             Timer(const Duration(seconds: 2), () => setState(() => _activeEmoji = null));
//             return;
//           }
//           setState(() => _lastTranscript = text);
//         })
//         ..on<RoomDisconnectedEvent>((_) => _safeExit());

//       await _room!.connect("wss://key-5d1ldsh2.livekit.cloud", token);
//       await _room!.localParticipant?.setMicrophoneEnabled(true);
//       await _room!.setSpeakerOn(_isSpeakerOn);

//       _startTimers();
//       _startVisionLoop();
//       if (mounted) setState(() { _isConnected = true; _lastTranscript = "Listening..."; });
//     } catch (e) {
//       _log("FATAL", e);
//       if (mounted) setState(() => _hasError = true);
//     }
//   }

//   void _startTimers() {
//     // Stats timer — updates audio levels + drives mouth animation
//     _statsTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
//       if (_room == null || !mounted) return;
//       final rawAi = _room!.remoteParticipants.values.firstOrNull?.audioLevel ?? 0;
//       final rawUser = _room!.localParticipant?.audioLevel ?? 0;

//       // Exponential smoothing — fast attack (0.5) slow release (0.85)
//       // so mouth snaps open quickly but closes more gradually (natural)
//       final smoothed = rawAi > _smoothedAiLevel
//           ? _smoothedAiLevel * 0.5 + rawAi * 0.5   // fast open
//           : _smoothedAiLevel * 0.85 + rawAi * 0.15; // slow close
//       // Micro-noise while talking for organic feel
//       final noise = rawAi > 0.005
//           ? (math.Random().nextDouble() - 0.5) * 0.15
//           : 0.0;

//       setState(() {
//         _aiLevel = rawAi;
//         _userLevel = rawUser;
//         _smoothedAiLevel = smoothed;
//         _mouthNoise = noise;
//       });
//     });

//     _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
//       if (!mounted) return;
//       setState(() {
//         _seconds++;
//         _secondsRemaining = (_secondsRemaining - 1).clamp(0, _dailyLimitSeconds);
//       });
//       if (_seconds % 30 == 0) _reportUsage();
//       if (_secondsRemaining <= 0) _safeExit();
//     });
//   }

//   Future<void> _safeExit() async {
//     if (_exited) return;
//     _exited = true;

//     _statsTimer?.cancel();
//     _durationTimer?.cancel();
//     _textFadeTimer?.cancel();
//     _visionTimer?.cancel();
//     _visionCommentTimer?.cancel();
//     _blinkTimer?.cancel();
//     _mouthController.dispose();
//     _blinkController.dispose();
//     _breathController.dispose();

//     try { await _cameraController?.dispose(); } catch (_) {}

//     final delta = _seconds - _lastSavedSeconds;
//     final prefs = await SharedPreferences.getInstance();
//     if (delta > 0 && _deviceId.isNotEmpty) {
//       final pending = (prefs.getInt("pending_call_seconds") ?? 0) + delta;
//       await prefs.setInt("pending_call_seconds", pending);
//       await prefs.setString("pending_call_device_id", _deviceId);
//     }

//     final reported = await _reportCallEnded();
//     if (reported) {
//       await prefs.remove("pending_call_seconds");
//       await prefs.remove("pending_call_device_id");
//     }

//     try {
//       final userId = prefs.getString("sympy_user_id") ?? "";
//       if (userId.isNotEmpty) {
//         await http.post(
//           Uri.parse("https://web-production-6c359.up.railway.app/call/summary"),
//           headers: {"X-API-KEY": AppSecrets.appApiKey, "X-User-Id": userId},
//         ).timeout(const Duration(seconds: 10));
//       }
//     } catch (_) {}

//     try {
//       if (_room != null) {
//         await _room!.localParticipant?.unpublishAllTracks();
//         await _room!.disconnect();
//         await _listener?.dispose();
//         await _room!.dispose();
//       }
//       _room = null;
//     } catch (_) {}

//     if (mounted) Navigator.pop(context);
//   }

//   String _time() =>
//       "${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}";

//   @override
//   void dispose() {
//     if (!_exited) {
//       _exited = true;
//       _statsTimer?.cancel();
//       _durationTimer?.cancel();
//       _textFadeTimer?.cancel();
//       _visionTimer?.cancel();
//       _visionCommentTimer?.cancel();
//       _blinkTimer?.cancel();
//       try { _mouthController.dispose(); } catch (_) {}
//       try { _blinkController.dispose(); } catch (_) {}
//       try { _breathController.dispose(); } catch (_) {}
//       try { _cameraController?.dispose(); } catch (_) {}
//     }
//     super.dispose();
//   }

//   // ─────────────────────────────────────────────────────────────────────────
//   // BUILD
//   // ─────────────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF060714),
//       body: SafeArea(child: _hasError ? _buildErrorView() : _buildCallView()),
//     );
//   }

//   Widget _buildErrorView() {
//     return Container(
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Color(0xFF060714), Color(0xFF0d0d2b), Color(0xFF060714)],
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//         ),
//       ),
//       child: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(24),
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: Colors.redAccent.withOpacity(0.1),
//                 border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
//               ),
//               child: const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
//             ),
//             const SizedBox(height: 24),
//             const Text("Connection Failed",
//                 style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 8),
//             Text("Something went wrong. Try again.",
//                 style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
//             const SizedBox(height: 40),
//             GestureDetector(
//               onTap: _connect,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(30),
//                   gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent]),
//                 ),
//                 child: const Text("Try Again",
//                     style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCallView() {
//     if (_quotaExhausted) return _buildQuotaExhaustedView();

//     final aiName = widget.voice == "male" ? "Buddy" : "Missy";
//     final size = MediaQuery.of(context).size;

//     return Stack(
//       fit: StackFit.expand,
//       children: [

//         // ══════════════════════════════════════════════════════════════════
//         // LAYER 1 — Full-screen AI avatar (the "remote" side like WhatsApp)
//         // ══════════════════════════════════════════════════════════════════
//         _buildFullScreenAvatar(aiName, size),

//         // ══════════════════════════════════════════════════════════════════
//         // LAYER 2 — Top gradient overlay (status bar area)
//         // ══════════════════════════════════════════════════════════════════
//         Positioned(
//           top: 0, left: 0, right: 0,
//           child: Container(
//             height: 140,
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//                 colors: [Color(0xCC000000), Colors.transparent],
//               ),
//             ),
//           ),
//         ),

//         // ══════════════════════════════════════════════════════════════════
//         // LAYER 3 — Bottom gradient overlay (controls area)
//         // ══════════════════════════════════════════════════════════════════
//         Positioned(
//           bottom: 0, left: 0, right: 0,
//           child: Container(
//             height: 220,
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.bottomCenter,
//                 end: Alignment.topCenter,
//                 colors: [Color(0xEE000000), Colors.transparent],
//               ),
//             ),
//           ),
//         ),

//         // ══════════════════════════════════════════════════════════════════
//         // LAYER 4 — Top bar: AI name, timer, quota
//         // ══════════════════════════════════════════════════════════════════
//         Positioned(
//           top: 0, left: 0, right: 0,
//           child: SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               child: Row(
//                 children: [
//                   // Live badge
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: (_isConnected ? Colors.green : Colors.blueAccent).withOpacity(0.2),
//                       borderRadius: BorderRadius.circular(20),
//                       border: Border.all(
//                           color: (_isConnected ? Colors.green : Colors.blueAccent).withOpacity(0.5)),
//                     ),
//                     child: Row(children: [
//                       Container(
//                         width: 6, height: 6,
//                         decoration: BoxDecoration(
//                           color: _isConnected ? Colors.green : Colors.blueAccent,
//                           shape: BoxShape.circle,
//                         ),
//                       ),
//                       const SizedBox(width: 5),
//                       Text(
//                         _isConnected ? "Live" : "Connecting",
//                         style: TextStyle(
//                           color: _isConnected ? Colors.green : Colors.blueAccent,
//                           fontSize: 11, fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ]),
//                   ),

//                   const Spacer(),

//                   // AI name + timer stacked
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//                       Text(aiName,
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 17,
//                             fontWeight: FontWeight.w700,
//                             letterSpacing: 0.3,
//                           )),
//                       Text(
//                         _isConnected ? _time() : "Connecting...",
//                         style: TextStyle(
//                           color: Colors.white.withOpacity(0.65),
//                           fontSize: 13,
//                           fontFamily: 'monospace',
//                           letterSpacing: 2,
//                         ),
//                       ),
//                     ],
//                   ),

//                   const Spacer(),

//                   // Remaining time pill
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: (_secondsRemaining <= 30 ? Colors.redAccent : Colors.white)
//                           .withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(
//                         color: (_secondsRemaining <= 30 ? Colors.redAccent : Colors.white)
//                             .withOpacity(0.25),
//                       ),
//                     ),
//                     child: Text(
//                       "⏱ ${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}",
//                       style: TextStyle(
//                         color: _secondsRemaining <= 30 ? Colors.redAccent : Colors.white70,
//                         fontSize: 11,
//                         fontWeight: _secondsRemaining <= 30 ? FontWeight.bold : FontWeight.normal,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),

//         // ══════════════════════════════════════════════════════════════════
//         // LAYER 5 — Transcript bubble (centre-bottom of avatar area)
//         // ══════════════════════════════════════════════════════════════════
//         Positioned(
//           bottom: 170,
//           left: 20, right: 20,
//           child: AnimatedOpacity(
//             opacity: _lastTranscript.isNotEmpty ? 1.0 : 0.0,
//             duration: const Duration(milliseconds: 300),
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
//               decoration: BoxDecoration(
//                 color: Colors.black.withOpacity(0.55),
//                 borderRadius: BorderRadius.circular(18),
//                 border: Border.all(color: Colors.white.withOpacity(0.1)),
//               ),
//               child: Text(
//                 _lastTranscript,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 14,
//                   fontStyle: FontStyle.italic,
//                   height: 1.4,
//                 ),
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//           ),
//         ),

//         // ══════════════════════════════════════════════════════════════════
//         // LAYER 6 — Bottom controls
//         // ══════════════════════════════════════════════════════════════════
//         Positioned(
//           bottom: 0, left: 0, right: 0,
//           child: SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // Waveform row
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       _VideoWaveWidget(
//                         level: _isMuted ? 0 : _userLevel,
//                         color: _isMuted ? Colors.redAccent : Colors.greenAccent,
//                       ),
//                       const SizedBox(width: 10),
//                       Text(
//                         _isMuted ? "🔇 Muted" : "🎙 You",
//                         style: TextStyle(
//                           color: (_isMuted ? Colors.redAccent : Colors.greenAccent).withOpacity(0.8),
//                           fontSize: 11, fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 14),

//                   // Control buttons row
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       _callButton(
//                         icon: _isMuted ? Icons.mic_off : Icons.mic,
//                         label: _isMuted ? "Unmute" : "Mute",
//                         active: !_isMuted,
//                         onTap: () async {
//                           setState(() => _isMuted = !_isMuted);
//                           await _room?.localParticipant?.setMicrophoneEnabled(!_isMuted);
//                         },
//                       ),
//                       // Big red end-call button
//                       GestureDetector(
//                         onTap: _safeExit,
//                         child: Container(
//                           width: 68, height: 68,
//                           decoration: BoxDecoration(
//                             shape: BoxShape.circle,
//                             color: Colors.redAccent,
//                             boxShadow: [BoxShadow(
//                               color: Colors.redAccent.withOpacity(0.5),
//                               blurRadius: 20, spreadRadius: 2,
//                             )],
//                           ),
//                           child: const Icon(Icons.call_end, color: Colors.white, size: 28),
//                         ),
//                       ),
//                       _callButton(
//                         icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
//                         label: _isSpeakerOn ? "Speaker" : "Earpiece",
//                         active: _isSpeakerOn,
//                         onTap: () async {
//                           setState(() => _isSpeakerOn = !_isSpeakerOn);
//                           await _room?.setSpeakerOn(_isSpeakerOn);
//                         },
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),

//         // ══════════════════════════════════════════════════════════════════
//         // LAYER 7 — Draggable camera PiP (user's face, top-right corner)
//         // ══════════════════════════════════════════════════════════════════
//         if (_cameraReady && _cameraEnabled)
//           Builder(builder: (ctx) {
//             final sz = MediaQuery.of(ctx).size;
//             // Set default top-right position once we know the screen size
//             if (_pipOffset == null) {
//               _pipOffset = Offset(sz.width - 110 - 16, 90);
//             }
//             return _buildDraggablePiP(sz);
//           }),

//         // ══════════════════════════════════════════════════════════════════
//         // LAYER 8 — AI vision comment toast
//         // ══════════════════════════════════════════════════════════════════
//         if (_aiVisionComment != null)
//           _buildVisionToast(),

//         // ══════════════════════════════════════════════════════════════════
//         // LAYER 9 — Emoji reaction
//         // ══════════════════════════════════════════════════════════════════
//         if (_activeEmoji != null)
//           Center(child: Text(_activeEmoji!, style: const TextStyle(fontSize: 120))),
//       ],
//     );
//   }

//   // ══════════════════════════════════════════════════════════════════════════
//   // Full-screen avatar — fills the entire screen like WhatsApp remote video
//   // ══════════════════════════════════════════════════════════════════════════
//   Widget _buildFullScreenAvatar(String aiName, Size size) {
//     // Amplify strongly — LiveKit levels are tiny (0.001-0.15).
//     // We need mouth to visibly open even at low volumes.
//     final mouth = (_smoothedAiLevel * 18.0 + _mouthNoise * 2).clamp(0.0, 1.0);
//     final isTalking = mouth > 0.05;

//     return AnimatedBuilder(
//       animation: _breathController,
//       builder: (_, child) {
//         // Very subtle scale breath — just enough to feel alive
//         final scale = 1.0 + _breathController.value * 0.006;
//         return Transform.scale(scale: scale, child: child);
//       },
//       child: Stack(
//         fit: StackFit.expand,
//         children: [
//           // ── Base avatar image fills entire screen ──
//           Image.asset(
//             widget.imagePath,
//             fit: BoxFit.cover,
//             width: size.width,
//             height: size.height,
//             errorBuilder: (_, __, ___) => Container(
//               decoration: const BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [Color(0xFF0d0d2b), Color(0xFF060714)],
//                   begin: Alignment.topCenter,
//                   end: Alignment.bottomCenter,
//                 ),
//               ),
//               child: const Center(
//                 child: Icon(Icons.person, color: Colors.white38, size: 100),
//               ),
//             ),
//           ),

//           // ── Slight dark vignette so avatar doesn't compete with controls ──
//           Container(
//             decoration: BoxDecoration(
//               gradient: RadialGradient(
//                 center: Alignment.center,
//                 radius: 1.0,
//                 colors: [
//                   Colors.transparent,
//                   Colors.black.withOpacity(0.25),
//                 ],
//               ),
//             ),
//           ),

//           // ── Mouth overlay — widget-based, always visible ──
//           // Positioned at the lower-centre of the screen where the face is.
//           // AnimatedContainer scales height with audio level.
//           Positioned(
//             left: size.width * 0.5 - size.width * 0.14,
//             top: size.height * 0.60,
//             child: _buildMouthWidget(mouth, size),
//           ),

//           // ── Blink overlay ──
//           if (_isBlinking)
//             _buildBlinkOverlay(size),

//           // ── Speaking glow pulse on the avatar ──
//           if (isTalking)
//             Positioned.fill(
//               child: AnimatedOpacity(
//                 opacity: isTalking ? (0.05 + mouth * 0.12) : 0.0,
//                 duration: const Duration(milliseconds: 80),
//                 child: Container(
//                   decoration: BoxDecoration(
//                     gradient: RadialGradient(
//                       center: const Alignment(0, -0.15),
//                       radius: 0.7,
//                       colors: [
//                         Colors.blueAccent.withOpacity(0.35),
//                         Colors.transparent,
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),

//           // ── Speaking sound rings (emanating from face area) ──
//           if (isTalking)
//             Positioned(
//               left: 0, right: 0,
//               top: size.height * 0.25,
//               child: Center(
//                 child: Stack(
//                   alignment: Alignment.center,
//                   children: List.generate(3, (i) => _buildPulseRing(i, mouth)),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }


//   // Widget-based mouth — scales visibly with audio level
//   Widget _buildMouthWidget(double openAmount, Size size) {
//     final w = size.width * 0.28;
//     final maxH = size.height * 0.055;
//     final h = (openAmount * maxH).clamp(2.0, maxH);
//     final isOpen = openAmount > 0.08;

//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 60),
//       curve: Curves.easeOut,
//       width: w,
//       height: h.clamp(4.0, maxH),
//       child: CustomPaint(
//         painter: _MouthShapePainter(
//           openAmount: openAmount,
//           isOpen: isOpen,
//         ),
//       ),
//     );
//   }

//   // Blink overlay — two skin-tone ovals over the eyes
//   Widget _buildBlinkOverlay(Size size) {
//     return Positioned.fill(
//       child: CustomPaint(
//         painter: _BlinkPainter(),
//       ),
//     );
//   }

//   Widget _buildPulseRing(int index, double mouth) {
//     return TweenAnimationBuilder<double>(
//       tween: Tween(begin: 0.0, end: 1.0),
//       duration: Duration(milliseconds: 1200 + index * 300),
//       curve: Curves.easeOut,
//       builder: (_, v, __) {
//         final base = 80.0;
//         return Container(
//           width: base + v * (60 + index * 20),
//           height: base + v * (60 + index * 20),
//           decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             border: Border.all(
//               color: Colors.blueAccent.withOpacity((1 - v) * 0.35 * mouth),
//               width: 1.5,
//             ),
//           ),
//         );
//       },
//     );
//   }

//   // ─── AI waveform ─────────────────────────────────────────────────────────
//   Widget _buildAIWave() {
//     return SizedBox(
//       height: 36,
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: List.generate(24, (i) {
//           final center = 11.5;
//           final base = 4.0;
//           final noiseAdd = i % 3 == 0 ? _mouthNoise * 8 : 0.0;
//           final peak = base + ((_smoothedAiLevel * 75 + noiseAdd) *
//               (1 - ((i - center).abs() / center).clamp(0.0, 1.0)));
//           final h = peak.clamp(base, 36.0);
//           return AnimatedContainer(
//             duration: const Duration(milliseconds: 80),
//             margin: const EdgeInsets.symmetric(horizontal: 1.5),
//             width: 3,
//             height: h,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(2),
//               gradient: LinearGradient(
//                 colors: [
//                   Colors.blueAccent.withOpacity(0.9),
//                   Colors.purpleAccent.withOpacity(0.5),
//                 ],
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//               ),
//             ),
//           );
//         }),
//       ),
//     );
//   }

//   // ─── Draggable camera PiP ─────────────────────────────────────────────────
//   Widget _buildDraggablePiP(Size size) {
//     final pipW = _pipExpanded ? 160.0 : 110.0;
//     final pipH = _pipExpanded ? 213.0 : 150.0;
//     final offset = _pipOffset ?? Offset(size.width - pipW - 16, 90);

//     return Positioned(
//       left: offset.dx,
//       top: offset.dy,
//       child: GestureDetector(
//         onPanUpdate: (d) {
//           setState(() {
//             final cur = _pipOffset ?? Offset(size.width - pipW - 16, 90);
//             _pipOffset = Offset(
//               (cur.dx + d.delta.dx).clamp(0, size.width - pipW),
//               (cur.dy + d.delta.dy).clamp(0, size.height - pipH),
//             );
//           });
//         },
//         onTap: () => setState(() => _pipExpanded = !_pipExpanded),
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 200),
//           curve: Curves.easeOut,
//           width: pipW,
//           height: pipH,
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
//             boxShadow: [BoxShadow(
//               color: Colors.black.withOpacity(0.5),
//               blurRadius: 12, offset: const Offset(0, 4),
//             )],
//           ),
//           child: ClipRRect(
//             borderRadius: BorderRadius.circular(15),
//             child: Stack(
//               children: [
//                 // Camera preview — fill the container
//                 if (_cameraController != null && _cameraController!.value.isInitialized)
//                   SizedBox.expand(
//                     child: FittedBox(
//                       fit: BoxFit.cover,
//                       child: SizedBox(
//                         width: _cameraController!.value.previewSize?.height ?? 100,
//                         height: _cameraController!.value.previewSize?.width ?? 100,
//                         child: CameraPreview(_cameraController!),
//                       ),
//                     ),
//                   )
//                 else
//                   Container(
//                     color: const Color(0xFF1a1a2e),
//                     child: const Center(
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(Icons.videocam, color: Colors.white54, size: 28),
//                           SizedBox(height: 4),
//                           Text("Camera", style: TextStyle(color: Colors.white38, fontSize: 10)),
//                         ],
//                       ),
//                     ),
//                   ),

//                 // Camera off button
//                 Positioned(
//                   top: 6, right: 6,
//                   child: GestureDetector(
//                     onTap: () => setState(() => _cameraEnabled = false),
//                     child: Container(
//                       padding: const EdgeInsets.all(4),
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.6),
//                         shape: BoxShape.circle,
//                       ),
//                       child: const Icon(Icons.close, color: Colors.white70, size: 12),
//                     ),
//                   ),
//                 ),

//                 // "You" label
//                 Positioned(
//                   bottom: 6, left: 8,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                     decoration: BoxDecoration(
//                       color: Colors.black.withOpacity(0.5),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: const Text("You",
//                         style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // ─── AI vision toast ──────────────────────────────────────────────────────
//   Widget _buildVisionToast() {
//     return Positioned(
//       bottom: 130,
//       left: 20, right: 20,
//       child: AnimatedOpacity(
//         opacity: _aiVisionComment != null ? 1.0 : 0.0,
//         duration: const Duration(milliseconds: 400),
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//           decoration: BoxDecoration(
//             color: Colors.blueAccent.withOpacity(0.18),
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: Colors.blueAccent.withOpacity(0.35)),
//             boxShadow: [BoxShadow(
//               color: Colors.blueAccent.withOpacity(0.15),
//               blurRadius: 20,
//             )],
//           ),
//           child: Row(children: [
//             const Icon(Icons.visibility, color: Colors.blueAccent, size: 16),
//             const SizedBox(width: 8),
//             Expanded(
//               child: Text(
//                 _aiVisionComment ?? "",
//                 style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//           ]),
//         ),
//       ),
//     );
//   }

//   // ─── Quota exhausted ──────────────────────────────────────────────────────
//   Widget _buildQuotaExhaustedView() {
//     final now = DateTime.now().toUtc();
//     final midnight = DateTime.utc(now.year, now.month, now.day + 1);
//     final diff = midnight.difference(now);
//     final hoursLeft = diff.inHours;
//     final minsLeft = diff.inMinutes % 60;
//     final resetText = hoursLeft > 0
//         ? "$hoursLeft hr${hoursLeft > 1 ? 's' : ''} ${minsLeft > 0 ? '$minsLeft min' : ''}".trim()
//         : "${minsLeft > 0 ? '$minsLeft min' : 'less than a minute'}";

//     return Container(
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Color(0xFF060714), Color(0xFF0d0d2b), Color(0xFF060714)],
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//         ),
//       ),
//       child: Center(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 32),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(24),
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: Colors.white.withOpacity(0.04),
//                   border: Border.all(color: Colors.white.withOpacity(0.08)),
//                   boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.25), blurRadius: 40, spreadRadius: 4)],
//                 ),
//                 child: const Icon(Icons.timer_off_outlined, color: Colors.redAccent, size: 48),
//               ),
//               const SizedBox(height: 28),
//               const Text("Daily Limit Reached",
//                   style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
//               const SizedBox(height: 12),
//               Text("You've used your 5 minutes for today.",
//                   style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15, height: 1.5),
//                   textAlign: TextAlign.center),
//               const SizedBox(height: 24),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.04),
//                   borderRadius: BorderRadius.circular(18),
//                   border: Border.all(color: Colors.white.withOpacity(0.08)),
//                 ),
//                 child: Column(children: [
//                   Text("Resets in",
//                       style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12, letterSpacing: 1)),
//                   const SizedBox(height: 6),
//                   Text(resetText,
//                       style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
//                   const SizedBox(height: 4),
//                   Text("midnight UTC",
//                       style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11)),
//                 ]),
//               ),
//               const SizedBox(height: 32),
//               GestureDetector(
//                 onTap: () => Navigator.pop(context),
//                 child: Container(
//                   width: double.infinity, height: 52,
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(16),
//                     gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent]),
//                     boxShadow: [BoxShadow(
//                       color: Colors.blueAccent.withOpacity(0.35),
//                       blurRadius: 20, offset: const Offset(0, 8),
//                     )],
//                   ),
//                   child: const Center(
//                     child: Text("Got it, come back tomorrow!",
//                         style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // ─── Small labelled call button ───────────────────────────────────────────
//   Widget _callButton({
//     required IconData icon,
//     required String label,
//     required bool active,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Column(children: [
//         Container(
//           width: 56, height: 56,
//           decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             color: active ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.05),
//             border: Border.all(
//                 color: active ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.08)),
//           ),
//           child: Icon(icon, color: active ? Colors.white : Colors.white38, size: 24),
//         ),
//         const SizedBox(height: 6),
//         Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
//       ]),
//     );
//   }

//   // keep old _circle for backward compat — unused in new UI
//   Widget _circle(IconData icon, bool active, VoidCallback onTap, {bool red = false}) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.all(18),
//         decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             color: red ? Colors.red : (active ? Colors.white12 : Colors.red.withOpacity(0.2))),
//         child: Icon(icon, color: Colors.white, size: 28),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // MouthPainter — draws a realistic open/close mouth + eye blink overlay
// // on top of the avatar image using canvas drawing.
// // openAmount: 0.0 = fully closed, 1.0 = wide open
// // ─────────────────────────────────────────────────────────────────────────────
// class _MouthShapePainter extends CustomPainter {
//   final double openAmount;
//   final bool isOpen;
//   _MouthShapePainter({required this.openAmount, required this.isOpen});

//   @override
//   void paint(Canvas canvas, Size size) {
//     final cx = size.width / 2;
//     final cy = size.height * 0.45;
//     final w  = size.width;
//     final h  = size.height;

//     if (isOpen && h > 3) {
//       // ── Outer lip ──
//       final lipPaint = Paint()
//         ..color = const Color(0xFF1a0000).withOpacity(0.95)
//         ..style = PaintingStyle.fill;
//       final lip = Path()
//         ..moveTo(0, cy)
//         ..cubicTo(w * 0.2, cy - h * 0.3, w * 0.8, cy - h * 0.3, w, cy)
//         ..cubicTo(w * 0.8, cy + h * 0.85, w * 0.2, cy + h * 0.85, 0, cy)
//         ..close();
//       canvas.drawPath(lip, lipPaint);

//       // ── Inner cavity ──
//       final innerPaint = Paint()
//         ..color = const Color(0xFF050000).withOpacity(0.98)
//         ..style = PaintingStyle.fill;
//       final inner = Path()
//         ..moveTo(w * 0.08, cy)
//         ..cubicTo(w * 0.25, cy - h * 0.2, w * 0.75, cy - h * 0.2, w * 0.92, cy)
//         ..cubicTo(w * 0.75, cy + h * 0.7, w * 0.25, cy + h * 0.7, w * 0.08, cy)
//         ..close();
//       canvas.drawPath(inner, innerPaint);

//       // ── Teeth ──
//       if (openAmount > 0.25) {
//         final tp = (openAmount - 0.25).clamp(0.0, 0.9);
//         canvas.drawRRect(
//           RRect.fromRectAndRadius(
//             Rect.fromCenter(
//               center: Offset(cx, cy + h * 0.12),
//               width: w * 0.72, height: h * 0.28,
//             ),
//             const Radius.circular(3),
//           ),
//           Paint()..color = Colors.white.withOpacity(tp),
//         );
//       }

//       // ── Lip sheen ──
//       canvas.drawPath(
//         Path()
//           ..moveTo(w * 0.1, cy)
//           ..cubicTo(w * 0.3, cy - h * 0.22, w * 0.7, cy - h * 0.22, w * 0.9, cy),
//         Paint()
//           ..color = Colors.white.withOpacity(0.18)
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = 1.2
//           ..strokeCap = StrokeCap.round,
//       );
//     } else {
//       // ── Closed — curved smile line ──
//       canvas.drawPath(
//         Path()
//           ..moveTo(0, cy)
//           ..cubicTo(w * 0.3, cy + h * 0.15, w * 0.7, cy + h * 0.15, w, cy),
//         Paint()
//           ..color = const Color(0xFF1a0000).withOpacity(0.7)
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = (size.width * 0.04).clamp(2.0, 6.0)
//           ..strokeCap = StrokeCap.round,
//       );
//     }
//   }

//   @override
//   bool shouldRepaint(_MouthShapePainter old) =>
//       old.openAmount != openAmount || old.isOpen != isOpen;
// }


// class _BlinkPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     // Semi-transparent skin-tone ovals over both eyes
//     final p = Paint()
//       ..color = const Color(0xFFc08860).withOpacity(0.9)
//       ..style = PaintingStyle.fill;
//     for (final cx in [size.width * 0.36, size.width * 0.64]) {
//       canvas.drawOval(
//         Rect.fromCenter(
//           center: Offset(cx, size.height * 0.42),
//           width: size.width * 0.13,
//           height: size.height * 0.038,
//         ),
//         p,
//       );
//     }
//   }
//   @override
//   bool shouldRepaint(_BlinkPainter _) => false;
// }


// // ─────────────────────────────────────────────────────────────────────────────
// // WaveWidget — kept exactly as original for compatibility
// // ─────────────────────────────────────────────────────────────────────────────
// class _VideoWaveWidget extends StatelessWidget {
//   final double level;
//   final Color color;
//   const _VideoWaveWidget({super.key, required this.level, required this.color});

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: List.generate(20, (i) {
//         final center = 9.5;
//         final base = 6.0;
//         final peak = base + (level * 80 * (1 - ((i - center).abs() / center)));
//         final h = peak.clamp(base, 80.0);
//         return AnimatedContainer(
//           duration: const Duration(milliseconds: 100),
//           margin: const EdgeInsets.symmetric(horizontal: 2),
//           width: 3,
//           height: h,
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(2),
//             gradient: LinearGradient(
//               colors: [color.withOpacity(0.9), color.withOpacity(0.4)],
//               begin: Alignment.topCenter,
//               end: Alignment.bottomCenter,
//             ),
//           ),
//         );
//       }),
//     );
//   }
// }