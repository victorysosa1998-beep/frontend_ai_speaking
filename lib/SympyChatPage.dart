import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math';
import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:animate_do/animate_do.dart';
import 'package:uuid/uuid.dart';
import 'call_screen.dart';
import 'secrets.dart';

class SympyChatPage extends StatefulWidget {
  final String voice;
  final String vibe;
  final String imagePath; // added

  const SympyChatPage({
    super.key,
    required this.voice,
    required this.vibe,
    required this.imagePath, // added
  });

  @override
  State<SympyChatPage> createState() => _SympyChatPageState();
}

class _SympyChatPageState extends State<SympyChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late ConfettiController _confettiController;

  final String apiKey = AppSecrets.appApiKey;
  final String sessionId = const Uuid().v4();
  late final String chatEndpoint =
      "http://192.168.253.157:8000/chat?voice=${widget.voice}&vibe=${widget.vibe}";

  List<({String role, String text})> messages = [];
  bool isSending = false;

  // Kinetic UX state
  int comboStreak = 0;
  DateTime? lastMessageTime;
  bool comboMode = false;

  String getAIName() =>
      widget.voice.toLowerCase() == 'male' ? 'Buddy' : 'Missy';

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    // Initial welcome
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendInitialGreeting();
    });
  }

  void _sendInitialGreeting() {
    final firstGreeting = "Hey, hi! ... I'm ${getAIName()}, nice to meet you.";
    final secondGreeting =
        "So, what do I call you and what language would you like to chat with today, English or Pidgin?";

    setState(() {
      messages.add((role: "sympy", text: firstGreeting));
      _listKey.currentState?.insertItem(messages.length - 1);
      messages.add((role: "sympy", text: secondGreeting));
      _listKey.currentState?.insertItem(messages.length - 1);
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateCombo() {
    final now = DateTime.now();
    if (lastMessageTime == null) {
      comboStreak = 1;
    } else {
      final diff = now.difference(lastMessageTime!);
      if (diff.inSeconds <= 30) {
        comboStreak++;
      } else {
        comboStreak = 1;
      }
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();

    setState(() {
      _updateCombo();
      messages.add((role: "user", text: text));
      _listKey.currentState?.insertItem(messages.length - 1);
      isSending = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final contextData = messages
          .map(
            (m) => {
              "role": m.role == "user" ? "user" : "assistant",
              "content": m.text,
            },
          )
          .toList();

      final response = await http
          .post(
            Uri.parse(chatEndpoint),
            headers: {
              "Content-Type": "application/json",
              "X-API-KEY": apiKey,
              "X-SESSION-ID": sessionId,
            },
            body: jsonEncode({"message": text, "context": contextData}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String reply = data["reply"] ?? "I'm vibing, but I'm lost for words.";

        if (reply.toLowerCase().contains("haha") || reply.contains("😂")) {
          _confettiController.play();
        }

        setState(() {
          messages.add((role: "sympy", text: reply));
          _listKey.currentState?.insertItem(messages.length - 1);
        });
      } else {
        _handleError("Server error: ${response.statusCode}");
      }
    } catch (e) {
      _handleError("Network issue. Try again!");
    } finally {
      if (mounted) setState(() => isSending = false);
      _scrollToBottom();
    }
  }

  void _handleError(String errorText) {
    setState(() {
      messages.add((role: "sympy", text: errorText));
      _listKey.currentState?.insertItem(messages.length - 1);
    });
  }

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

  Widget _kineticText(String text, bool isUser) {
    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      from: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: isUser
              ? Colors.blueAccent.withOpacity(0.9)
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 20),
          ),
          border: Border.all(color: Colors.white10),
        ),
        child: Text(
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
    ({String role, String text}) message,
    Animation<double> animation,
  ) {
    bool isUser = message.role == "user";
    return SizeTransition(
      sizeFactor: animation,
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: _kineticText(message.text, isUser),
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
                  boxShadow: [
                    if (comboMode)
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                  ],
                ),
              ),
            ],
          ),
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
      appBar: AppBar(
        title: Text(
          getAIName(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
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
                Expanded(
                  child: AnimatedList(
                    key: _listKey,
                    controller: _scrollController,
                    initialItemCount: messages.length,
                    padding: const EdgeInsets.only(top: 100, bottom: 20),
                    itemBuilder: (context, index, animation) =>
                        _buildMessage(messages[index], animation),
                  ),
                ),
                if (isSending) _typingBubble(),
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
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: "Talk your mind...",
                                  hintStyle: TextStyle(color: Colors.white38),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 15,
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
                              onPressed: isSending ? null : _sendMessage,
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
      if (!mounted) break;
      setState(() => _opacity = 1.0);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) break;
      setState(() => _opacity = 0.2);
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
