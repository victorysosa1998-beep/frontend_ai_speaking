import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math';
import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:animate_do/animate_do.dart';
import 'call_screen.dart';

class SympyChatPage extends StatefulWidget {
  final String voice;
  final String vibe;
  const SympyChatPage({super.key, required this.voice, required this.vibe});

  @override
  State<SympyChatPage> createState() => _SympyChatPageState();
}

class _SympyChatPageState extends State<SympyChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late ConfettiController _confettiController;

  final String apiKey = "<YOUR_TOKEN_API_KEY>";
  late final String chatEndpoint =
      "http://192.168.253.157:8000/chat?voice=${widget.voice}&vibe=${widget.vibe}";

  List<({String role, String text})> messages = [];
  bool isSending = false;

  int comboStreak = 0;
  DateTime? lastMessageTime;
  bool comboMode = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
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

  bool _isSlangWord(String w) {
    final word = w.toLowerCase();
    return word == "lol" ||
        word == "lmao" ||
        word == "fr" ||
        word.contains("😂");
  }

  Widget _kineticText(String text, ThemeData theme) {
    final words = text.split(" ");

    return Wrap(
      children: words.map((w) {
        final clean = w.replaceAll(RegExp(r'[^\w😂]'), '');

        if (_isSlangWord(clean)) {
          if (clean.toLowerCase() == "lol") {
            return JelloIn(
              duration: const Duration(milliseconds: 600),
              child: Text(
                "$w ",
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }

          if (clean.toLowerCase() == "fr") {
            return Swing(
              duration: const Duration(milliseconds: 600),
              child: Text(
                "$w ",
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }

          return ShakeX(
            duration: const Duration(milliseconds: 550),
            child: Text(
              "$w ",
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        return Text("$w ", style: theme.textTheme.bodyMedium);
      }).toList(),
    );
  }

  Widget _energyMeter() {
    double progress = (comboStreak / 10).clamp(0.0, 1.0);

    return FadeIn(
      duration: const Duration(milliseconds: 250),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: comboMode ? Colors.pinkAccent : Colors.white24,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "🔥 ${comboStreak}x",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 70,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() async {
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
            headers: {"Content-Type": "application/json", "x-api-key": apiKey},
            body: jsonEncode({"message": text, "context": contextData}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          HapticFeedback.mediumImpact();
          String reply = data["reply"];

          if (reply.toLowerCase().contains("haha") ||
              reply.toLowerCase().contains("cool") ||
              reply.toLowerCase().contains("yay")) {
            _confettiController.play();
          }

          setState(() {
            messages.add((role: "sympy", text: reply));
            _listKey.currentState?.insertItem(messages.length - 1);
          });
        }
      } else {
        _handleError("Oops! Something went wrong.");
      }
    } catch (e) {
      _handleError("Network error. Please check your connection.");
    } finally {
      if (mounted) setState(() => isSending = false);
      _scrollToBottom();
    }
  }

  void _handleError(String errorText) {
    if (mounted) {
      setState(() {
        messages.add((role: "sympy", text: errorText));
        _listKey.currentState?.insertItem(messages.length - 1);
      });
    }
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

  void _startCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(vibe: widget.vibe, voice: widget.voice),
      ),
    );
  }

  Color _getVibeColor(bool isUser) {
    if (isUser) return Colors.blue.withOpacity(0.15);
    switch (widget.vibe.toLowerCase()) {
      case 'chill':
        return Colors.teal.withOpacity(0.12);
      case 'energetic':
        return Colors.orange.withOpacity(0.12);
      default:
        return Colors.white.withOpacity(0.1);
    }
  }

  Widget _typingBubble() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TypingDot(),
                  SizedBox(width: 5),
                  _TypingDot(delay: 150),
                  SizedBox(width: 5),
                  _TypingDot(delay: 300),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(
    ({String role, String text}) message,
    Animation<double> animation,
  ) {
    final bool isUser = message.role == "user";
    final theme = Theme.of(context);

    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    "Sympy AI",
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              GestureDetector(
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: message.text));
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Message copied to clipboard"),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: _getVibeColor(isUser),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 16),
                        ),
                      ),
                      child: _kineticText(message.text, theme),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: Colors.white,
          size: 30,
          weight: 700,
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Colors.blue, Colors.purple],
            ),
          ),
        ),
        elevation: 0,
        title: Text(
          "Chat with Sympy AI",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.phone), onPressed: _startCall),
        ],
      ),
      body: Stack(
        children: [
          if (comboMode)
            Positioned.fill(
              child: Pulse(
                infinite: true,
                duration: const Duration(milliseconds: 1200),
                child: Container(color: Colors.pinkAccent.withOpacity(0.04)),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(top: kToolbarHeight + topPadding),
            child: Column(
              children: [
                Expanded(
                  child: AnimatedList(
                    key: _listKey,
                    controller: _scrollController,
                    initialItemCount: messages.length,
                    itemBuilder: (context, index, animation) =>
                        _buildMessage(messages[index], animation),
                  ),
                ),
                if (isSending) _typingBubble(),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              decoration: InputDecoration(
                                hintText: "Type a message...",
                                filled: true,
                                fillColor: theme.colorScheme.surfaceVariant
                                    .withOpacity(0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton.filled(
                            onPressed: isSending ? null : _sendMessage,
                            icon: isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: kToolbarHeight + topPadding + 10,
            right: 12,
            child: _energyMeter(),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              blastDirection: -pi / 2,
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
      duration: const Duration(milliseconds: 600),
      opacity: _opacity,
      child: const CircleAvatar(radius: 3.5),
    );
  }
}
