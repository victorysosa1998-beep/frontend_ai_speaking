import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loveable/RingingCallPage.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'call_screen.dart';
import 'secrets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'HistoryPage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SympyChatPage extends StatefulWidget {
  final String voice;
  final String vibe;
  final String imagePath;

  const SympyChatPage({
    super.key,
    required this.voice,
    required this.vibe,
    required this.imagePath,
  });

  @override
  State<SympyChatPage> createState() => _SympyChatPageState();
}

class _SympyChatPageState extends State<SympyChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final GlobalKey _shareCardKey = GlobalKey();
  late ConfettiController _confettiController;
  late stt.SpeechToText _speech;

  bool _isListening = false;
  String _voiceBuffer = "";
  bool _greetingShown = false;
  int? _highlightIndex;
  Uint8List? _pendingImage;
  String _knownName = "";
  String _knownLang = "";
  int _streak = 0;
  String _currentMood = "";
  String _lastCallSummary = "";
  String _lastChatSummary = "";
  final List<DateTime> _timestamps = [];
  final List<String?> _retryTexts = [];

  final String apiKey = AppSecrets.appApiKey;
  String _userId = "";

  List<({String role, String text, Uint8List? image})> messages = [];
  bool isSending = false;

  int comboStreak = 0;
  DateTime? lastMessageTime;
  bool comboMode = false;

  String get _aiName => widget.voice == "male" ? "Buddy" : "Missy";

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _speech = stt.SpeechToText();

    _initUserId().then((_) async {
      await _loadUserProfile();
      await _loadStreak();
      await _loadLastCallSummary();
      await _loadLastChatSummary();
      if (!_greetingShown && messages.isEmpty) {
        setState(() => _greetingShown = true);
        _sendInitialGreeting();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // =================== USER ID ===================
  Future<void> _initUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
    if (firebaseUid != null) {
      final userId = "user_$firebaseUid";
      await prefs.setString("sympy_user_id", userId);
      setState(() => _userId = userId);
      return;
    }
    String? stored = prefs.getString("sympy_user_id");
    if (stored == null) {
      final rand = DateTime.now().millisecondsSinceEpoch.toString();
      stored = "user_${rand.substring(rand.length - 10)}";
      await prefs.setString("sympy_user_id", stored);
    }
    setState(() => _userId = stored!);
  }

  // =================== USER PROFILE ===================
  Future<void> _loadUserProfile() async {
    if (_userId.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse("https://web-production-6c359.up.railway.app/user_profile"),
        headers: {"X-API-KEY": apiKey, "X-User-Id": _userId},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String backendName = data["known_name"] ?? "";
        String backendLang = data["known_lang"] ?? "";
        if (backendName.isEmpty) {
          final firebaseName =
              FirebaseAuth.instance.currentUser?.displayName ?? "";
          if (firebaseName.isNotEmpty) {
            backendName = firebaseName;
            _seedNameToBackend(firebaseName);
          }
        }
        setState(() {
          _knownName = backendName;
          _knownLang = backendLang;
        });
      }
    } catch (_) {}
  }

  Future<void> _seedNameToBackend(String name) async {
    if (_userId.isEmpty || name.isEmpty) return;
    try {
      await http.post(
        Uri.parse("https://web-production-6c359.up.railway.app/set_name"),
        headers: {
          "Content-Type": "application/json",
          "X-API-KEY": apiKey,
          "X-User-Id": _userId,
        },
        body: jsonEncode({"name": name}),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // =================== STREAK ===================
  Future<void> _loadStreak() async {
    if (_userId.isEmpty) return;
    try {
      final res = await http.get(
        Uri.parse("https://web-production-6c359.up.railway.app/streak"),
        headers: {"X-API-KEY": apiKey, "X-User-Id": _userId},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        setState(() => _streak = d["streak"] ?? 0);
      }
    } catch (_) {}
  }

  Future<void> _checkInStreak() async {
    if (_userId.isEmpty) return;
    try {
      final res = await http.post(
        Uri.parse(
            "https://web-production-6c359.up.railway.app/streak/checkin"),
        headers: {"X-API-KEY": apiKey, "X-User-Id": _userId},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final newStreak = d["streak"] ?? 0;
        final isNew = d["is_new"] ?? false;
        setState(() => _streak = newStreak);
        if (isNew && mounted && newStreak > 1) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Text("🔥 ", style: TextStyle(fontSize: 20)),
              Text("$newStreak day streak! Keep it up!",
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
            backgroundColor: Colors.deepOrange,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (_) {}
  }

  // =================== MOOD ===================
  Future<void> _logMood() async {
    if (_userId.isEmpty) return;
    try {
      final res = await http.post(
        Uri.parse("https://web-production-6c359.up.railway.app/mood/log"),
        headers: {"X-API-KEY": apiKey, "X-User-Id": _userId},
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d["mood"] != null) setState(() => _currentMood = d["mood"]);
      }
    } catch (_) {}
  }

  // =================== CALL SUMMARY ===================
  Future<void> _loadLastCallSummary() async {
    if (_userId.isEmpty) return;
    try {
      final res = await http.get(
        Uri.parse(
            "https://web-production-6c359.up.railway.app/call/last_summary"),
        headers: {"X-API-KEY": apiKey, "X-User-Id": _userId},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if ((d["summary"] ?? "").isNotEmpty) {
          setState(() => _lastCallSummary = d["summary"]);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadLastChatSummary() async {
    if (_userId.isEmpty) return;
    try {
      final res = await http.get(
        Uri.parse(
            "https://web-production-6c359.up.railway.app/chat/last_summary"),
        headers: {"X-API-KEY": apiKey, "X-User-Id": _userId},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if ((d["summary"] ?? "").isNotEmpty) {
          setState(() => _lastChatSummary = d["summary"]);
        }
      }
    } catch (_) {}
  }

  // =================== SHARE MOMENT ===================
  Widget _buildShareCard(
      List<({String role, String text, Uint8List? image})> recent) {
    return RepaintBoundary(
      key: _shareCardKey,
      child: Container(
        width: 380,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF060714), Color(0xFF0d0d2b), Color(0xFF060714)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              left: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              bottom: 60,
              right: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purpleAccent.withOpacity(0.07),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.signal_cellular_alt,
                            color: Colors.white54, size: 14),
                        const SizedBox(width: 4),
                        const Icon(Icons.wifi, color: Colors.white54, size: 14),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.green.withOpacity(0.4)),
                        ),
                        child: Row(children: [
                          Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          const Text("Live",
                              style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      const Icon(Icons.battery_full,
                          color: Colors.white54, size: 14),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5),
                      BoxShadow(
                          color: Colors.purpleAccent.withOpacity(0.3),
                          blurRadius: 50,
                          spreadRadius: 10),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.blueAccent, Colors.purpleAccent],
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        widget.imagePath,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 90,
                          height: 90,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [
                              Colors.blueAccent,
                              Colors.purpleAccent
                            ]),
                          ),
                          child: const Icon(Icons.person,
                              color: Colors.white, size: 40),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _aiName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "AI Companion · Sympy",
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 12),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(20, (i) {
                    final heights = [
                      8.0, 14.0, 20.0, 28.0, 18.0, 24.0, 32.0,
                      20.0, 14.0, 26.0, 30.0, 18.0, 22.0, 28.0,
                      16.0, 24.0, 20.0, 14.0, 18.0, 10.0
                    ];
                    return Container(
                      width: 3,
                      height: heights[i],
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(
                          colors: [Colors.blueAccent, Colors.purpleAccent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: recent.map((m) {
                      final isUser = m.role == "user";
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: isUser
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isUser) ...[
                              ClipOval(
                                child: Image.asset(
                                  widget.imagePath,
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 24,
                                    height: 24,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(colors: [
                                        Colors.blueAccent,
                                        Colors.purpleAccent
                                      ]),
                                    ),
                                    child: const Icon(Icons.auto_awesome,
                                        color: Colors.white, size: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: isUser
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFF4776E6),
                                            Color(0xFF8E54E9)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: isUser
                                      ? null
                                      : Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft:
                                        Radius.circular(isUser ? 16 : 0),
                                    bottomRight:
                                        Radius.circular(isUser ? 0 : 16),
                                  ),
                                ),
                                child: Text(
                                  m.text,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [
                            Colors.blueAccent,
                            Colors.purpleAccent
                          ]),
                        ),
                        child: const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 14),
                      ),
                      const SizedBox(width: 10),
                      const Text("Sympy AI",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List?> _captureCardBytes() async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      final RenderRepaintBoundary? boundary = _shareCardKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Capture failed: $e");
      return null;
    }
  }

  Future<void> _shareImageBytes(Uint8List bytes,
      List<({String role, String text, Uint8List? image})> recent) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
          "${dir.path}/sympy_moment_${DateTime.now().millisecondsSinceEpoch}.png");
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: "image/png")],
          subject: "My convo with $_aiName on Sympy 🔥",
          text: "🔥 My chat with $_aiName\n\n👇 Download Sympy\nhttps://www.sympy-ai.info/getapp.html",
        ),
      );
    } catch (e) {
      debugPrint("Share image failed: $e");
      final lines = recent
          .map((m) => "${m.role == "user" ? "Me" : _aiName}: ${m.text}")
          .join("\n");
      await SharePlus.instance.share(
        ShareParams(
            text:
                "Me and $_aiName on Sympy 👇\n\n$lines\n\n🔥 https://www.sympy-ai.info/getapp.html"),
      );
    }
  }

  /// Shares the conversation as plain text with the download link
  /// appended separately — so the URL is clickable in WhatsApp, iMessage etc.
  Future<void> _shareAsLink(
      List<({String role, String text, Uint8List? image})> recent) async {
    final lines = recent
        .where((m) => m.text.isNotEmpty)
        .map((m) => "${m.role == "user" ? "Me" : _aiName}: ${m.text}")
        .join("\n");
   await SharePlus.instance.share(
  ShareParams(
    text: "My chat with $_aiName on Sympy 🔥\n\n$lines\n\nhttps://www.sympy-ai.info/getapp.html",
    subject: "Check out Sympy — Nigerian AI Bestie",
  ),
);
  }

  void _showShareMoment() {
    final allMessages = messages.where((m) => m.text.isNotEmpty).toList();
    if (allMessages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Start a conversation first!"),
        backgroundColor: Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final recent = allMessages.length > 4
        ? allMessages.sublist(allMessages.length - 4)
        : allMessages;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0d0d1a),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _buildShareCard(recent),
                      ),
                      const SizedBox(height: 16),
                      // ── Two share options ─────────────────────
                      // 1. Share as Image — saves card as PNG (no live link)
                      // 2. Share Link    — plain text + clickable URL
                      Column(
                        children: [
                          Row(children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.blueAccent.withOpacity(0.2),
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                          color: Colors.blueAccent
                                              .withOpacity(0.4))),
                                ),
                                icon: const Icon(Icons.image_rounded,
                                    color: Colors.white),
                                label: const Text("Share as Image",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  final bytes = await _captureCardBytes();
                                  if (mounted) Navigator.pop(context);
                                  if (bytes != null) {
                                    await _shareImageBytes(bytes, recent);
                                  } else {
                                    await _shareAsLink(recent);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.1)),
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white54, size: 20),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          // Share Link button — sends text + clickable URL
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.purpleAccent.withOpacity(0.15),
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                        color: Colors.purpleAccent
                                            .withOpacity(0.4))),
                              ),
                              icon: const Icon(Icons.link_rounded,
                                  color: Colors.purpleAccent),
                              label: const Text("Share with Link",
                                  style: TextStyle(
                                      color: Colors.purpleAccent,
                                      fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                if (mounted) Navigator.pop(context);
                                await _shareAsLink(recent);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =================== CONTEXT BUILDER ===================
  List<Map<String, String>> _buildContext() {
    return messages
        .where((m) => m.text.isNotEmpty)
        .map((m) => {
              "role": m.role == "user" ? "user" : "assistant",
              "content": m.text,
            })
        .toList();
  }

  // =================== PERSISTENT HISTORY ===================
  Future<void> _saveConversation() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> savedMessages = messages
        .where((m) => m.text.isNotEmpty)
        .map((m) => jsonEncode({
              "role": m.role,
              "content": m.text,
            }))
        .toList();
    if (savedMessages.isEmpty) return;
    final key = DateTime.now().millisecondsSinceEpoch.toString();
    await prefs.setStringList(key, savedMessages);
    final allKeys = prefs.getStringList("conversation_keys") ?? [];
    allKeys.add(key);
    await prefs.setStringList("conversation_keys", allKeys);
  }

  Future<Map<String, List<Map<String, dynamic>>>>
      _loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getStringList("conversation_keys") ?? [];
    Map<String, List<Map<String, dynamic>>> result = {};
    for (var key in allKeys) {
      final conv = prefs.getStringList(key) ?? [];
      final decoded = conv
          .map((m) => Map<String, dynamic>.from(jsonDecode(m)))
          .toList();
      result[key] = decoded;
    }
    return result;
  }

  void _openHistory() async {
    final allConversations = await _loadConversations();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryPage(
          conversations: allConversations,
          onSelectConversation: (selectedHistory) {
            final listState = _listKey.currentState;
            for (int i = messages.length - 1; i >= 0; i--) {
              final msg = messages[i];
              listState?.removeItem(
                i,
                (context, animation) =>
                    _buildMessage(msg, animation, i),
                duration: const Duration(milliseconds: 0),
              );
            }
            setState(() {
              messages = [];
              _timestamps.clear();
              _retryTexts.clear();
              _greetingShown = true;
            });
            Future.delayed(Duration.zero, () {
              final newMessages = selectedHistory
                  .map<({String role, String text, Uint8List? image})>(
                    (m) => (
                      role: m['role'] == 'user' ? 'user' : 'sympy',
                      text: m['content'] ?? "",
                      image: null,
                    ),
                  )
                  .toList();
              for (int i = 0; i < newMessages.length; i++) {
                messages.add(newMessages[i]);
                _timestamps.add(DateTime.now());
                _retryTexts.add(null);
                listState?.insertItem(i);
              }
              setState(() => _highlightIndex = messages.length - 1);
              _scrollToBottom();
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) setState(() => _highlightIndex = null);
              });
            });
          },
        ),
      ),
    );
  }

  // =================== INITIAL GREETING ===================
  void _sendInitialGreeting() {
    final String intro;
    if (_knownName.isNotEmpty) {
      intro = _knownLang == "pidgin"
          ? "Eh $_knownName! Na me $_aiName 👋 Wetin dey your mind today?"
          : "Hey $_knownName! I'm $_aiName 👋 What's on your mind today?";
    } else {
      intro =
          "Hey! I'm $_aiName 👋 What do I call you, and do you prefer English or Pidgin?";
    }
    setState(() {
      messages.add((role: "sympy", text: intro, image: null));
      _timestamps.add(DateTime.now());
      _retryTexts.add(null);
      _listKey.currentState?.insertItem(messages.length - 1);
    });
    _scrollToBottom();
  }

  String getAIName() => _aiName;

  void _updateCombo() {
    final now = DateTime.now();
    if (lastMessageTime == null) {
      comboStreak = 1;
    } else {
      final diff = now.difference(lastMessageTime!);
      comboStreak = diff.inSeconds <= 30 ? comboStreak + 1 : 1;
    }
    lastMessageTime = now;
    comboMode = comboStreak >= 10;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // =================== SEND MESSAGE ===================
  Future<void> _sendMessage({String? text, Uint8List? image}) async {
    final messageText = text ?? _controller.text.trim();
    // Resolve image: explicit param first, then pending preview
    final Uint8List? imageToSend = image ?? _pendingImage;
    if (messageText.isEmpty && imageToSend == null) return;
    if (isSending) return;

    // Clear pending image preview
    if (_pendingImage != null) setState(() => _pendingImage = null);

    HapticFeedback.lightImpact();

    final lowerText = messageText.toLowerCase();
    if (lowerText.contains("call me") || lowerText.contains("lol")) {
      _confettiController.play();
      if (lowerText.contains("call me")) {
        final regex =
            RegExp(r"call me (?:as\s+)?(.+)", caseSensitive: false);
        final match = regex.firstMatch(messageText);
        String extractedName = "User";
        if (match != null && match.group(1) != null) {
          extractedName =
              match.group(1)!.trim().replaceAll(RegExp(r'[?.!]$'), '');
        }
        _controller.clear();
        unawaited(_startRingingCall(extractedName));
        return;
      }
    }

    // Add user message bubble (shows image thumbnail if image present)
    setState(() {
      _updateCombo();
      messages.add((role: "user", text: messageText, image: imageToSend));
      _timestamps.add(DateTime.now());
      _retryTexts.add(null);
      _listKey.currentState?.insertItem(messages.length - 1);
      isSending = true;
    });

    _controller.clear();
    _scrollToBottom();

    // ── IMAGE PATH ──────────────────────────────────────────────
    // Sends image as raw bytes (Content-Type: application/octet-stream).
    // Caption is passed as a URL query parameter to avoid multipart entirely.
    // This is the most reliable approach — no python-multipart dependency needed.
    if (imageToSend != null) {
      try {
        // Build URL — append caption as query param if user typed something
        final String baseUrl =
            "https://web-production-6c359.up.railway.app/image_search";
        final Uri uri = messageText.isNotEmpty
            ? Uri.parse(
                "$baseUrl?caption=${Uri.encodeComponent(messageText)}")
            : Uri.parse(baseUrl);

        final response = await http
            .post(
              uri,
              headers: {
                "Content-Type": "application/octet-stream",
                "X-API-KEY": apiKey,
                "X-User-Id": _userId,
              },
              body: imageToSend,
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (mounted) {
            setState(() {
              messages.add((
                role: "sympy",
                text: data["reply"] ?? "I see that!",
                image: null,
              ));
              _timestamps.add(DateTime.now());
              _retryTexts.add(null);
              _listKey.currentState?.insertItem(messages.length - 1);
            });
          }
        } else {
          _handleError(
            _knownLang == "pidgin"
                ? "Oops! I no fit analyse the image 🙈"
                : "Oops! Image analysis failed.",
          );
        }
      } catch (e) {
        _handleError(
          _knownLang == "pidgin"
              ? "Oops! Network wahala 😅"
              : "Oops! Connection dropped.",
        );
      } finally {
        if (mounted) setState(() => isSending = false);
        _scrollToBottom();
        await _saveConversation();
      }
      return; // never fall through to text block
    }

    // ── TEXT PATH ───────────────────────────────────────────────
    try {
      final response = await http
          .post(
            Uri.parse(
                "https://web-production-6c359.up.railway.app/chat?voice=${widget.voice}&vibe=${widget.vibe}"),
            headers: {
              "Content-Type": "application/json",
              "X-API-KEY": apiKey,
              "X-User-Id": _userId,
            },
            body: jsonEncode({
              "message": messageText,
              "context": _buildContext(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data["reply"];
        final replyText = reply is String
            ? reply
            : "I'm vibing, but I'm lost for words.";
        if (data["known_name"] != null &&
            (data["known_name"] as String).isNotEmpty) {
          setState(() {
            _knownName = data["known_name"];
            _knownLang = data["known_lang"] ?? _knownLang;
          });
        }
        if (replyText.toLowerCase().contains("haha") ||
            replyText.contains("😂")) {
          _confettiController.play();
        }
        if (mounted) {
          setState(() {
            messages.add((role: "sympy", text: replyText, image: null));
            _timestamps.add(DateTime.now());
            _retryTexts.add(null);
            _listKey.currentState?.insertItem(messages.length - 1);
          });
        }
      } else {
        _handleError(
          _knownLang == "pidgin"
              ? "Oops! Something no go well 😅"
              : "Oops! Something went wrong.",
          retryText: messageText,
        );
      }
    } catch (e) {
      _handleError(
        _knownLang == "pidgin"
            ? "Oops! Network wahala 🙏"
            : "Oops! Lost connection.",
        retryText: messageText,
      );
    } finally {
      if (mounted) setState(() => isSending = false);
      _scrollToBottom();
      await _saveConversation();
      await _checkInStreak();
      await _logMood();
    }
  }

  void _handleError(String errorText, {String? retryText}) {
    if (mounted) {
      setState(() {
        messages.add((role: "sympy", text: errorText, image: null));
        _timestamps.add(DateTime.now());
        _retryTexts.add(retryText);
        _listKey.currentState?.insertItem(messages.length - 1);
      });
    }
  }

  // =================== CAMERA + GALLERY ===================
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    XFile? picked;

    final choice = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Select source'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'camera'),
            child: const Text('Camera'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'gallery'),
            child: const Text('Gallery'),
          ),
        ],
      ),
    );

    if (choice == 'camera') {
      picked = await picker.pickImage(
          source: ImageSource.camera, imageQuality: 70);
    } else if (choice == 'gallery') {
      picked = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 70);
    }

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _pendingImage = bytes);
    }
  }

  // =================== VOICE ===================
  void _startRecording() async {
    bool available = await _speech.initialize(
      onError: (val) => debugPrint('STT Error: $val'),
      onStatus: (val) => debugPrint('STT Status: $val'),
    );
    if (available) {
      HapticFeedback.heavyImpact();
      _voiceBuffer = "";
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) => _voiceBuffer = result.recognizedWords,
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
      );
    }
  }

  void _stopRecording() async {
    HapticFeedback.mediumImpact();
    await _speech.stop();
    setState(() => _isListening = false);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (_voiceBuffer.trim().isNotEmpty) {
        _sendMessage(text: _voiceBuffer.trim());
        _voiceBuffer = "";
      }
    });
  }

  // =================== CALL ===================
  void _startCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          vibe: widget.vibe,
          voice: widget.voice,
          imagePath: widget.imagePath,
        ),
      ),
    );
  }

  Future<void> _startRingingCall(String nameForCallerId) async {
    String callVoice = widget.voice;
    String callerDisplayName = nameForCallerId;

    if (_userId.isNotEmpty) {
      try {
        final personaRes = await http.get(
          Uri.parse(
              "https://web-production-6c359.up.railway.app/fake_call/persona"),
          headers: {"X-API-KEY": apiKey, "X-User-Id": _userId},
        ).timeout(const Duration(seconds: 5));
        if (personaRes.statusCode == 200) {
          final persona =
              jsonDecode(personaRes.body) as Map<String, dynamic>;
          if (persona.isNotEmpty) {
            if (persona["voice"] != null) {
              callVoice = persona["voice"] as String;
            }
            if (persona["caller_name"] != null &&
                (persona["caller_name"] as String).isNotEmpty) {
              callerDisplayName = persona["caller_name"] as String;
            }
          }
        }
      } catch (_) {}
    }

    final callerImagePath = callVoice == "male"
        ? "assets/images/buddy.png"
        : "assets/images/missy.png";

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RingingCallScreen(
          callerName: callerDisplayName,
          onAccept: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CallScreen(
                  vibe: widget.vibe,
                  voice: callVoice,
                  imagePath: callerImagePath,
                ),
              ),
            );
          },
          onDecline: () {
            Navigator.pop(context);
            if (_userId.isNotEmpty) {
              http
                  .post(
                    Uri.parse(
                        "https://web-production-6c359.up.railway.app/fake_call/clear"),
                    headers: {
                      "X-API-KEY": apiKey,
                      "X-User-Id": _userId,
                    },
                  )
                  .catchError((_) => http.Response('', 200));
            }
          },
        ),
      ),
    );
  }

  // =================== WIDGETS ===================
  Widget _buildSummaryBanner({
    required String summary,
    required IconData icon,
    required Color accentColor,
    required String label,
    required String title,
  }) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF060714), Color(0xFF0d0d2b)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accentColor.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: accentColor, size: 20),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
              Divider(
                  color: Colors.white.withOpacity(0.08), height: 20),
              Text(summary,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.6)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: accentColor, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "$label: $summary",
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.keyboard_arrow_up,
              color: Colors.white30, size: 16),
        ]),
      ),
    );
  }

  Widget _kineticText(String text, bool isUser,
      [Uint8List? image, bool highlight = false]) {
    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      from: 10,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin:
            const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: highlight
              ? Colors.yellow.withOpacity(0.3)
              : (isUser
                  ? Colors.blueAccent.withOpacity(0.9)
                  : Colors.white.withOpacity(0.15)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 20),
          ),
          border: Border.all(color: Colors.white10),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(image,
                    width: 200, height: 200, fit: BoxFit.cover),
              )
            : SelectableText(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight:
                      isUser ? FontWeight.w500 : FontWeight.normal,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }

  Widget _buildMessage(
    ({String role, String text, Uint8List? image}) message,
    Animation<double> animation, [
    int? index,
  ]) {
    final isUser = message.role == "user";
    final highlight = index != null && index == _highlightIndex;
    final DateTime? ts =
        (index != null && index < _timestamps.length)
            ? _timestamps[index]
            : null;
    final timeStr = ts != null
        ? "${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}"
        : "";
    final String? retryText =
        (index != null && index < _retryTexts.length)
            ? _retryTexts[index]
            : null;

    return SizeTransition(
      sizeFactor: animation,
      child: Align(
        alignment:
            isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              _kineticText(
                  message.text, isUser, message.image, highlight),
              if (timeStr.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, bottom: 2),
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10,
                    ),
                  ),
                ),
              if (retryText != null)
                Padding(
                  padding: const EdgeInsets.only(
                      left: 12, right: 12, bottom: 6),
                  child: GestureDetector(
                    onTap: () {
                      if (index != null) {
                        setState(() {
                          if (index < messages.length)
                            messages.removeAt(index);
                          if (index < _timestamps.length)
                            _timestamps.removeAt(index);
                          if (index < _retryTexts.length)
                            _retryTexts.removeAt(index);
                          _listKey.currentState?.removeItem(
                            index,
                            (ctx, anim) => const SizedBox.shrink(),
                            duration:
                                const Duration(milliseconds: 150),
                          );
                          final userIdx = index - 1;
                          if (userIdx >= 0) {
                            if (userIdx < messages.length)
                              messages.removeAt(userIdx);
                            if (userIdx < _timestamps.length)
                              _timestamps.removeAt(userIdx);
                            if (userIdx < _retryTexts.length)
                              _retryTexts.removeAt(userIdx);
                            _listKey.currentState?.removeItem(
                              userIdx,
                              (ctx, anim) => const SizedBox.shrink(),
                              duration:
                                  const Duration(milliseconds: 150),
                            );
                          }
                        });
                      }
                      _sendMessage(text: retryText);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                Colors.blueAccent.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.refresh_rounded,
                              color: Colors.blueAccent, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            _knownLang == "pidgin"
                                ? "Try again"
                                : "Tap to retry",
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TypingDot(delay: 0),
            SizedBox(width: 4),
            _TypingDot(delay: 200),
            SizedBox(width: 4),
            _TypingDot(delay: 400),
          ],
        ),
      ),
    );
  }

  Widget _energyMeter() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (comboMode)
              Pulse(
                infinite: true,
                child: Container(
                  height: 110,
                  width: 12,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 100,
              width: 6,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: (comboStreak.clamp(0, 20) / 20) * 100,
                    width: 6,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.orange, Colors.redAccent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "${comboStreak}x",
          style: const TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              ListTile(
                title: const Text("Conversation History"),
                leading: const Icon(Icons.history),
                onTap: _openHistory,
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Text(
          getAIName(),
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 26),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          if (_streak > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 4),
              child: Chip(
                label: Text("🔥 $_streak",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                backgroundColor: Colors.deepOrange.withOpacity(0.8),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.auto_awesome,
                color: Colors.white70, size: 22),
            onPressed: _showShareMoment,
            tooltip: "Share this moment",
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: _startCall,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(widget.imagePath, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                if (_lastChatSummary.isNotEmpty)
                  _buildSummaryBanner(
                    summary: _lastChatSummary,
                    icon: Icons.chat_bubble_outline,
                    accentColor: Colors.blueAccent,
                    label: "Last chat",
                    title: "Last Chat",
                  ),
                if (_lastCallSummary.isNotEmpty)
                  _buildSummaryBanner(
                    summary: _lastCallSummary,
                    icon: Icons.phone_in_talk,
                    accentColor: Colors.purpleAccent,
                    label: "Last call",
                    title: "Last Call",
                  ),
                if (_currentMood.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 2),
                    child: Row(children: [
                      const Icon(Icons.mood,
                          color: Colors.white30, size: 14),
                      const SizedBox(width: 4),
                      Text("Vibe: $_currentMood",
                          style: const TextStyle(
                              color: Colors.white30, fontSize: 11)),
                    ]),
                  ),
                Expanded(
                  child: AnimatedList(
                    key: _listKey,
                    controller: _scrollController,
                    initialItemCount: messages.length,
                    padding:
                        const EdgeInsets.only(top: 100, bottom: 20),
                    itemBuilder: (context, index, animation) =>
                        _buildMessage(
                            messages[index], animation, index),
                  ),
                ),
                if (isSending) _typingBubble(),
                if (_pendingImage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.07),
                                Colors.white.withOpacity(0.03),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(14),
                                child: Image.memory(
                                  _pendingImage!,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(children: [
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent
                                            .withOpacity(0.2),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: const Text("📎 Image",
                                          style: TextStyle(
                                              color: Colors.blueAccent,
                                              fontSize: 10,
                                              fontWeight:
                                                  FontWeight.w600)),
                                    ),
                                  ]),
                                  const SizedBox(height: 6),
                                  const Text("Ready to send",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                      "Type a question or tap send",
                                      style: TextStyle(
                                          color: Colors.white
                                              .withOpacity(0.4),
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                          ]),
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _pendingImage = null),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white24),
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter:
                          ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        color: Colors.white.withOpacity(0.1),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8),
                                child: Icon(Icons.camera_alt,
                                    color: Colors.white),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                style: const TextStyle(
                                    color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: _isListening
                                      ? "Listening..."
                                      : "Talk your mind...",
                                  hintStyle: TextStyle(
                                    color: _isListening
                                        ? Colors.redAccent
                                        : Colors.white38,
                                    fontWeight: _isListening
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 15,
                                  ),
                                  suffixIcon: GestureDetector(
                                    onLongPress: _startRecording,
                                    onLongPressUp: _stopRecording,
                                    child: Icon(
                                      _isListening
                                          ? Icons.mic_off
                                          : Icons.mic,
                                      color: _isListening
                                          ? Colors.redAccent
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.send_rounded,
                                color: isSending
                                    ? Colors.white24
                                    : Colors.blueAccent,
                              ),
                              onPressed: isSending
                                  ? null
                                  : () => _sendMessage(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
                top: 120, right: 16, child: _energyMeter()),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                ],
                gravity: 0.1,
                numberOfParticles: 15,
                emissionFrequency: 0.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({this.delay = 0});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> {
  double _opacity = 0.2;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() async {
    await Future.delayed(Duration(milliseconds: widget.delay));
    while (mounted) {
      if (mounted) setState(() => _opacity = 1.0);
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _opacity = 0.2);
      await Future.delayed(const Duration(milliseconds: 600));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 600),
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}