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

  final String apiKey = AppSecrets.appApiKey;
  String _userId = ""; // stable per-device ID, loaded from SharedPreferences

  List<({String role, String text, Uint8List? image})> messages = [];
  bool isSending = false;

  int comboStreak = 0;
  DateTime? lastMessageTime;
  bool comboMode = false;

  // ✅ AI name always derived from voice — never hardcoded
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
    String? stored = prefs.getString("sympy_user_id");
    if (stored == null) {
      // Generate a UUID-like stable ID for this device
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
        setState(() {
          _knownName = data["known_name"] ?? "";
          _knownLang = data["known_lang"] ?? "";
        });
      }
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
        Uri.parse("https://web-production-6c359.up.railway.app/streak/checkin"),
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

  // =================== SHARE MOMENT ===================
  // Build share card that looks like the call screen
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
            // Background glow blobs
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
            // Main content
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 32),
                // Status bar mock
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
                          border:
                              Border.all(color: Colors.green.withOpacity(0.4)),
                        ),
                        child: Row(children: [
                          Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                  color: Colors.green, shape: BoxShape.circle)),
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
                // Avatar circle with glow
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
                // AI name
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
                // Fake waveform bars
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(20, (i) {
                    final heights = [
                      8.0,
                      14.0,
                      20.0,
                      28.0,
                      18.0,
                      24.0,
                      32.0,
                      20.0,
                      14.0,
                      26.0,
                      30.0,
                      18.0,
                      22.0,
                      28.0,
                      16.0,
                      24.0,
                      20.0,
                      14.0,
                      18.0,
                      10.0
                    ];
                    return Container(
                      width: 3,
                      height: heights[i],
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          colors: [Colors.blueAccent, Colors.purpleAccent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                // Chat bubbles
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
                                      : Colors.white.withOpacity(0.07),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft:
                                        Radius.circular(isUser ? 16 : 3),
                                    bottomRight:
                                        Radius.circular(isUser ? 3 : 16),
                                  ),
                                  border: isUser
                                      ? null
                                      : Border.all(
                                          color:
                                              Colors.white.withOpacity(0.08)),
                                ),
                                child: Text(
                                  m.text.length > 80
                                      ? "${m.text.substring(0, 80)}..."
                                      : m.text,
                                  style: TextStyle(
                                    color: isUser
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.85),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            if (isUser) const SizedBox(width: 8),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                // Divider
                Container(height: 1, color: Colors.white.withOpacity(0.06)),
                // Footer
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      // App icon placeholder
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4776E6), Color(0xFF8E54E9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Sympy AI",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            Text("Your Nigerian AI Bestie",
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4776E6), Color(0xFF8E54E9)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Download",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                // URL
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    "sympyapp.com/download",
                    style: TextStyle(
                        color: Colors.blueAccent.withOpacity(0.7),
                        fontSize: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Capture the share card to PNG bytes while it's still on screen
  Future<Uint8List?> _captureCardBytes() async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      final RenderRepaintBoundary? boundary = _shareCardKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Capture failed: $e");
      return null;
    }
  }

  // Share pre-captured bytes as image file
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
        ),
      );
    } catch (e) {
      debugPrint("Share image failed: $e");
      // Fallback text
      final lines = recent
          .map((m) => "${m.role == "user" ? "Me" : _aiName}: ${m.text}")
          .join("\n");
      await SharePlus.instance.share(
        ShareParams(
            text:
                "Me and $_aiName on Sympy 👇\n\n$lines\n\n🔥 sympyapp.com/download"),
      );
    }
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Preview card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _buildShareCard(recent),
                      ),
                      const SizedBox(height: 16),
                      // Share button row
                      Row(children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.blueAccent.withOpacity(0.2),
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                      color:
                                          Colors.blueAccent.withOpacity(0.4))),
                            ),
                            icon: const Icon(Icons.share_rounded,
                                color: Colors.white),
                            label: const Text("Share as Image",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              // ✅ Capture FIRST while card visible, THEN close, THEN share
                              final bytes = await _captureCardBytes();
                              if (mounted) Navigator.pop(context);
                              if (bytes != null) {
                                await _shareImageBytes(bytes, recent);
                              } else {
                                final lines = recent
                                    .map((m) =>
                                        "${m.role == "user" ? "Me" : _aiName}: ${m.text}")
                                    .join("\n");
                                await SharePlus.instance.share(ShareParams(
                                  text:
                                      "Me and $_aiName on Sympy 👇\n\n$lines\n\n🔥 sympyapp.com/download",
                                ));
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
  // ✅ KEY FIX: Sends the FULL conversation (current + loaded history) to backend.
  // This is what makes the AI remember everything — both within a session
  // and when history is loaded from SharedPreferences.
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

  Future<Map<String, List<Map<String, dynamic>>>> _loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getStringList("conversation_keys") ?? [];
    Map<String, List<Map<String, dynamic>>> result = {};

    for (var key in allKeys) {
      final conv = prefs.getStringList(key) ?? [];
      final decoded =
          conv.map((m) => Map<String, dynamic>.from(jsonDecode(m))).toList();
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
                (context, animation) => _buildMessage(msg, animation, i),
                duration: const Duration(milliseconds: 0),
              );
            }

            setState(() {
              messages = [];
              _greetingShown = true;
            });

            Future.delayed(Duration.zero, () {
              // ✅ FIX: Map roles correctly so _buildContext() sends them right
              // "user" → "user", anything else → "sympy" for display
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
          ? "Ehen $_knownName! Na me $_aiName 👋 Wetin dey your mind today?"
          : "Hey $_knownName! I'm $_aiName 👋 What's on your mind today?";
    } else {
      intro =
          "Hey! I'm $_aiName 👋 What do I call you, and do you prefer English or Pidgin?";
    }
    setState(() {
      messages.add((role: "sympy", text: intro, image: null));
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
    final Uint8List? imageToSend = image ?? _pendingImage;
    if (messageText.isEmpty && imageToSend == null) return;
    if (isSending) return;
    if (_pendingImage != null) setState(() => _pendingImage = null);

    HapticFeedback.lightImpact();

    final lowerText = messageText.toLowerCase();
    if (lowerText.contains("call me") || lowerText.contains("lol")) {
      _confettiController.play();
      if (lowerText.contains("call me")) {
        final regex = RegExp(r"call me (?:as\s+)?(.+)", caseSensitive: false);
        final match = regex.firstMatch(messageText);
        String extractedName = "User";
        if (match != null && match.group(1) != null) {
          extractedName =
              match.group(1)!.trim().replaceAll(RegExp(r'[?.!]$'), '');
        }
        _controller.clear();
        _startRingingCall(extractedName);
        return;
      }
    }

    setState(() {
      _updateCombo();
      messages.add((role: "user", text: messageText, image: image));
      _listKey.currentState?.insertItem(messages.length - 1);
      isSending = true;
    });

    _controller.clear();
    _scrollToBottom();

    // --- IMAGE ---
    if (image != null) {
      try {
        final response = await http
            .post(
              Uri.parse(
                  "https://web-production-6c359.up.railway.app/image_search"),
              headers: {
                "Content-Type": "application/octet-stream",
                "X-API-KEY": apiKey,
              },
              body: image,
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (mounted) {
            setState(() {
              messages.add((
                role: "sympy",
                text: data["reply"] ?? "I see that!",
                image: null
              ));
              _listKey.currentState?.insertItem(messages.length - 1);
            });
          }
        } else {
          _handleError("Image search failed! (${response.statusCode})");
        }
      } catch (e) {
        _handleError("Connection lost. My eyes are a bit blurry right now.");
      } finally {
        if (mounted) setState(() => isSending = false);
        _scrollToBottom();
        await _saveConversation();
      }
      return;
    }

    // --- IMAGE ---
    if (imageToSend != null) {
      try {
        setState(() {
          messages.add((role: "user", text: messageText, image: imageToSend));
          _listKey.currentState?.insertItem(messages.length - 1);
        });
        _scrollToBottom();
        final uri = Uri.parse(
            "https://web-production-6c359.up.railway.app/image_search");
        final request = http.MultipartRequest("POST", uri);
        request.headers["X-API-KEY"] = apiKey;
        request.headers["X-User-Id"] = _userId;
        if (messageText.isNotEmpty) request.fields["caption"] = messageText;
        request.files.add(http.MultipartFile.fromBytes("image", imageToSend,
            filename: "image.jpg"));
        final streamed =
            await request.send().timeout(const Duration(seconds: 30));
        final response = await http.Response.fromStream(streamed);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (mounted)
            setState(() {
              messages.add((
                role: "sympy",
                text: data["reply"] ?? "I see that!",
                image: null
              ));
              _listKey.currentState?.insertItem(messages.length - 1);
            });
        } else {
          _handleError("Image analysis failed! (${response.statusCode})");
        }
      } catch (e) {
        _handleError("Connection lost. Try again!");
      } finally {
        if (mounted) setState(() => isSending = false);
        _scrollToBottom();
        await _saveConversation();
      }
      return;
    }

    // --- TEXT ---
    try {
      final response = await http
          .post(
            Uri.parse(
                "https://web-production-6c359.up.railway.app/chat?voice=female&vibe=${widget.vibe}"),
            headers: {
              "Content-Type": "application/json",
              "X-API-KEY": apiKey,
              "X-User-Id": _userId, // ✅ stable per-device ID for Redis memory
            },
            // ✅ _buildContext() includes loaded history + current session messages
            body: jsonEncode({
              "message": messageText,
              "context": _buildContext(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data["reply"];
        final replyText =
            reply is String ? reply : "I'm vibing, but I'm lost for words.";
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
            _listKey.currentState?.insertItem(messages.length - 1);
          });
        }
      } else {
        _handleError("Server error: ${response.statusCode}");
      }
    } catch (e) {
      _handleError("Network issue. Try again!");
    } finally {
      if (mounted) setState(() => isSending = false);
      _scrollToBottom();
      await _saveConversation();
      await _checkInStreak();
      await _logMood();
    }
  }

  void _handleError(String errorText) {
    if (mounted) {
      setState(() {
        messages.add((role: "sympy", text: errorText, image: null));
        _listKey.currentState?.insertItem(messages.length - 1);
      });
    }
  }

  // =================== CAMERA + GALLERY ===================
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    XFile? image;

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
      image =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    } else if (choice == 'gallery') {
      image =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    }

    if (image != null) {
      final bytes = await image.readAsBytes();
      _sendMessage(image: bytes);
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
          voice: "female",
          imagePath: widget.imagePath,
        ),
      ),
    );
  }

  void _startRingingCall(String nameForCallerId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RingingCallScreen(
          callerName: nameForCallerId,
          onAccept: () {
            Navigator.pop(context);
            _startCall();
          },
          onDecline: () => Navigator.pop(context),
        ),
      ),
    );
  }

  // =================== WIDGETS ===================
  Widget _kineticText(String text, bool isUser,
      [Uint8List? image, bool highlight = false]) {
    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      from: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
                  fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
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
    return SizeTransition(
      sizeFactor: animation,
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: _kineticText(message.text, isUser, message.image, highlight),
        ),
      ),
    );
  }

  Widget _typingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          style:
              const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
            icon:
                const Icon(Icons.auto_awesome, color: Colors.white70, size: 22),
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
                if (_lastCallSummary.isNotEmpty)
                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (_) => Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: Colors.purpleAccent.withOpacity(0.3)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.phone_in_talk,
                                  color: Colors.purpleAccent, size: 20),
                              const SizedBox(width: 10),
                              const Text("Last Call Summary",
                                  style: TextStyle(
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
                            const Divider(color: Colors.white10, height: 20),
                            Text(
                              _lastCallSummary,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  height: 1.6),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withOpacity(0.07),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  setState(() => _lastCallSummary = "");
                                },
                                child: const Text("Dismiss",
                                    style: TextStyle(
                                        color: Colors.white54,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.purpleAccent.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.phone_in_talk,
                            color: Colors.purpleAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text("Last call: $_lastCallSummary",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const Icon(Icons.keyboard_arrow_up,
                            color: Colors.white30, size: 16),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() => _lastCallSummary = ""),
                          child: const Icon(Icons.close,
                              color: Colors.white30, size: 16),
                        ),
                      ]),
                    ),
                  ),
                if (_currentMood.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: Row(children: [
                      const Icon(Icons.mood, color: Colors.white30, size: 14),
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
                    padding: const EdgeInsets.only(top: 100, bottom: 20),
                    itemBuilder: (context, index, animation) =>
                        _buildMessage(messages[index], animation, index),
                  ),
                ),
                if (isSending) _typingBubble(),
                if (_pendingImage != null)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Main card
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
                            // Image with shadow
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.blueAccent.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text("📎 Image",
                                          style: TextStyle(
                                              color: Colors.blueAccent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ]),
                                  const SizedBox(height: 6),
                                  const Text("Ready to send",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text("Type a question or tap send",
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.4),
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                          ]),
                        ),
                        // X button floating top-right
                        Positioned(
                          top: -8,
                          right: -8,
                          child: GestureDetector(
                            onTap: () => setState(() => _pendingImage = null),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
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
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        color: Colors.white.withOpacity(0.1),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child:
                                    Icon(Icons.camera_alt, color: Colors.white),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                style: const TextStyle(color: Colors.white),
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
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 15,
                                  ),
                                  suffixIcon: GestureDetector(
                                    onLongPress: _startRecording,
                                    onLongPressUp: _stopRecording,
                                    child: Icon(
                                      _isListening ? Icons.mic_off : Icons.mic,
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
                              onPressed:
                                  isSending ? null : () => _sendMessage(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(top: 120, right: 16, child: _energyMeter()),
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
