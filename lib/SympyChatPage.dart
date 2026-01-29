// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:flutter/services.dart';
// import 'dart:ui';
// import 'dart:math';
// import 'dart:async';
// import 'package:confetti/confetti.dart';
// import 'package:animate_do/animate_do.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:loveable/RingingCallPage.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'call_screen.dart';
// import 'secrets.dart';
// import 'dart:typed_data';

// class SympyChatPage extends StatefulWidget {
//   final String voice;
//   final String vibe;
//   final String imagePath;

//   const SympyChatPage({
//     super.key,
//     required this.voice,
//     required this.vibe,
//     required this.imagePath,
//   });

//   @override
//   State<SympyChatPage> createState() => _SympyChatPageState();
// }

// class _SympyChatPageState extends State<SympyChatPage> {
//   final TextEditingController _controller = TextEditingController();
//   final ScrollController _scrollController = ScrollController();
//   final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
//   late ConfettiController _confettiController;
//   late stt.SpeechToText _speech;

//   bool _isListening = false;
//   String _voiceBuffer = "";

//   final String apiKey = AppSecrets.appApiKey;

//   List<({String role, String text, Uint8List? image})> messages = [];
//   bool isSending = false;

//   int comboStreak = 0;
//   DateTime? lastMessageTime;
//   bool comboMode = false;

//   @override
//   void initState() {
//     super.initState();
//     _confettiController = ConfettiController(duration: const Duration(seconds: 2));
//     _speech = stt.SpeechToText();

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _sendInitialGreeting();
//     });
//   }

//   void _sendInitialGreeting() {
//     final firstGreeting = "Hey, hi! ... I'm ${getAIName()}, nice to meet you.";
//     final secondGreeting =
//         "So, what do I call you and what language would you like to chat with today, English or Pidgin?";

//     setState(() {
//       messages.add((role: "sympy", text: firstGreeting, image: null));
//       _listKey.currentState?.insertItem(messages.length - 1);
//       messages.add((role: "sympy", text: secondGreeting, image: null));
//       _listKey.currentState?.insertItem(messages.length - 1);
//     });
//     _scrollToBottom();
//   }

//   String getAIName() => "Missy";

//   @override
//   void dispose() {
//     _confettiController.dispose();
//     _controller.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }

//   void _updateCombo() {
//     final now = DateTime.now();
//     if (lastMessageTime == null) {
//       comboStreak = 1;
//     } else {
//       final diff = now.difference(lastMessageTime!);
//       if (diff.inSeconds <= 30) {
//         comboStreak++;
//       } else {
//         comboStreak = 1;
//       }
//     }
//     lastMessageTime = now;
//     comboMode = comboStreak >= 10;
//   }

//   void _scrollToBottom() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 300),
//           curve: Curves.easeOutCubic,
//         );
//       }
//     });
//   }

//   // =================== UPDATED SEND MESSAGE WITH IMAGE SEARCH ===================
// Future<void> _sendMessage({String? text, Uint8List? image, int retryCount = 0}) async {
//   final messageText = text ?? _controller.text.trim();
//   if (messageText.isEmpty && image == null) return;

//   if (retryCount == 0) {
//     HapticFeedback.lightImpact();
//     setState(() {
//       _updateCombo();
//       if (image != null || messageText.isNotEmpty) {
//          messages.add((role: "user", text: messageText, image: image));
//          _listKey.currentState?.insertItem(messages.length - 1);
//       }
//       isSending = true;
//     });
//     _controller.clear();
//     _scrollToBottom();
//   }

//   // --- HANDLE IMAGE SEARCH ---
//   if (image != null) {
//     try {
//       // Add a temporary "Scanning image..." message
//       final tempMessage = (role: "sympy", text: "Scanning image...", image: null);
//       setState(() {
//         messages.add(tempMessage);
//         _listKey.currentState?.insertItem(messages.length - 1);
//       });
//       _scrollToBottom();

//       var request = http.MultipartRequest(
//         'POST', 
//         Uri.parse("https://web-production-6c359.up.railway.app/image_search")
//       );

//       request.headers.addAll({
//         "X-API-KEY": apiKey,
//         "Accept": "application/json",
//       });

//       request.files.add(
//         http.MultipartFile.fromBytes(
//           'file', 
//           image,
//           filename: 'upload.jpg',
//         ),
//       );

//       var streamedResponse = await request.send().timeout(const Duration(seconds: 25));
//       var response = await http.Response.fromStream(streamedResponse);

//       // Remove the temporary message safely
//       if (mounted && messages.isNotEmpty) {
//         final lastIndex = messages.length - 1;
//         final lastMessage = messages[lastIndex];
//         if (lastMessage.text == "Scanning image..." && lastMessage.role == "sympy") {
//           _listKey.currentState?.removeItem(
//             lastIndex,
//             (context, animation) => _buildMessage(lastMessage, animation),
//             duration: const Duration(milliseconds: 200),
//           );
//           messages.removeAt(lastIndex);
//         }
//       }

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         setState(() {
//           messages.add((role: "sympy", text: data["reply"] ?? "I see that!", image: null));
//           _listKey.currentState?.insertItem(messages.length - 1);
//           isSending = false;
//         });
//       } else if (response.statusCode == 413) {
//         _handleError("Abeg, this image too big! Try a smaller one.");
//         setState(() => isSending = false);
//       } else {
//         throw Exception("Server Error");
//       }
//     } catch (e) {
//       // Retry logic
//       if (retryCount < 2) {
//         print("Retrying image upload... attempt ${retryCount + 1}");
//         await Future.delayed(const Duration(seconds: 2));
//         return _sendMessage(text: messageText, image: image, retryCount: retryCount + 1);
//       }
//       _handleError("Connection lost. My eyes are a bit blurry right now.");
//       setState(() => isSending = false);
//     }
//     _scrollToBottom();
//     return;
//   }

//   // --- HANDLE REGULAR CHAT ---
//   try {
//     final contextData = messages
//         .map((m) => {
//               "role": m.role == "user" ? "user" : "assistant",
//               "content": m.text,
//             })
//         .toList();

//     final response = await http.post(
//       Uri.parse("https://web-production-6c359.up.railway.app/chat?voice=female&vibe=${widget.vibe}"),
//       headers: {
//         "Content-Type": "application/json",
//         "X-API-KEY": apiKey,
//       },
//       body: jsonEncode({"message": messageText, "context": contextData}),
//     ).timeout(const Duration(seconds: 15));

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       setState(() {
//         messages.add((role: "sympy", text: data["reply"] ?? "...", image: null));
//         _listKey.currentState?.insertItem(messages.length - 1);
//       });
//     } else {
//       throw Exception("Chat Error");
//     }
//   } catch (e) {
//     if (retryCount < 2) {
//       await Future.delayed(const Duration(seconds: 1));
//       return _sendMessage(text: messageText, retryCount: retryCount + 1);
//     }
//     _handleError("Vibe check failed. My signal is acting up!");
//   } finally {
//     if (mounted) setState(() => isSending = false);
//     _scrollToBottom();
//   }
// }

//   // =================== HELPER TO ADD SYMPY REPLY ===================
//   void _addSympyReply(String text) {
//     setState(() {
//       messages.add((role: "sympy", text: text, image: null));
//       _listKey.currentState?.insertItem(messages.length - 1);
//     });
//     _scrollToBottom();
//   }

//   void _handleError(String errorText) {
//     setState(() {
//       messages.add((role: "sympy", text: errorText, image: null));
//       _listKey.currentState?.insertItem(messages.length - 1);
//     });
//   }

//   // =================== CAMERA + GALLERY ===================
//   Future<void> _pickImage() async {
//     final picker = ImagePicker();
//     XFile? image;

//     final choice = await showDialog<String>(
//       context: context,
//       builder: (_) => SimpleDialog(
//         title: const Text('Select source'),
//         children: [
//           SimpleDialogOption(
//             onPressed: () => Navigator.pop(context, 'camera'),
//             child: const Text('Camera'),
//           ),
//           SimpleDialogOption(
//             onPressed: () => Navigator.pop(context, 'gallery'),
//             child: const Text('Gallery'),
//           ),
//         ],
//       ),
//     );

//     if (choice == 'camera') {
//       image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
//     } else if (choice == 'gallery') {
//       image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
//     }

//     if (image != null) {
//       final bytes = await image.readAsBytes();
//       _sendMessage(image: bytes);
//     }
//   }

//   // =================== VOICE ===================
//   void _startRecording() async {
//     bool available = await _speech.initialize(
//       onError: (val) => print('Engine Error: $val'),
//       onStatus: (val) => print('Engine Status: $val'),
//     );

//     if (available) {
//       HapticFeedback.heavyImpact();
//       _voiceBuffer = "";

//       setState(() {
//         _isListening = true;
//       });

//       await _speech.listen(
//         onResult: (result) {
//           _voiceBuffer = result.recognizedWords;
//         },
//         listenMode: stt.ListenMode.dictation,
//         partialResults: true,
//       );
//     }
//   }

//   void _stopRecording() async {
//     HapticFeedback.mediumImpact();
//     await _speech.stop();
//     setState(() => _isListening = false);

//     Future.delayed(const Duration(milliseconds: 250), () {
//       if (_voiceBuffer.trim().isNotEmpty) {
//         _sendMessage(text: _voiceBuffer.trim());
//         _voiceBuffer = "";
//       }
//     });
//   }

//   // =================== CALL LOGIC ===================
//   void _startCall() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => CallScreen(
//           vibe: widget.vibe,
//           voice: "female",
//           imagePath: widget.imagePath,
//         ),
//       ),
//     );
//   }

//   void _startRingingCall(String nameForCallerId) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => RingingCallScreen(
//           callerName: nameForCallerId,
//           onAccept: () {
//             Navigator.pop(context);
//             _startCall();
//           },
//           onDecline: () => Navigator.pop(context),
//         ),
//       ),
//     );
//   }

//   // =================== WIDGETS ===================
//   Widget _kineticText(String text, bool isUser, [Uint8List? image]) {
//     return FadeInUp(
//       duration: const Duration(milliseconds: 400),
//       from: 10,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
//         decoration: BoxDecoration(
//           color: isUser
//               ? Colors.blueAccent.withOpacity(0.9)
//               : Colors.white.withOpacity(0.15),
//           borderRadius: BorderRadius.only(
//             topLeft: const Radius.circular(20),
//             topRight: const Radius.circular(20),
//             bottomLeft: Radius.circular(isUser ? 20 : 0),
//             bottomRight: Radius.circular(isUser ? 0 : 20),
//           ),
//           border: Border.all(color: Colors.white10),
//         ),
//         child: image != null
//             ? ClipRRect(
//                 borderRadius: BorderRadius.circular(12),
//                 child: Image.memory(
//                   image,
//                   width: 200,
//                   height: 200,
//                   fit: BoxFit.cover,
//                 ),
//               )
//             : SelectableText(
//                 text,
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
//                   letterSpacing: 0.2,
//                 ),
//               ),
//       ),
//     );
//   }

//   Widget _buildMessage(
//       ({String role, String text, Uint8List? image}) message,
//       Animation<double> animation) {
//     bool isUser = message.role == "user";
//     return SizeTransition(
//       sizeFactor: animation,
//       child: Align(
//         alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 8.0),
//           child: _kineticText(message.text, isUser, message.image),
//         ),
//       ),
//     );
//   }

//   Widget _typingBubble() {
//     return Align(
//       alignment: Alignment.centerLeft,
//       child: Container(
//         margin: const EdgeInsets.all(12),
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//         decoration: BoxDecoration(
//           color: Colors.white10,
//           borderRadius: BorderRadius.circular(20),
//         ),
//         child: const Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             _TypingDot(delay: 0),
//             SizedBox(width: 4),
//             _TypingDot(delay: 200),
//             SizedBox(width: 4),
//             _TypingDot(delay: 400),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _energyMeter() {
//     return Column(
//       children: [
//         Stack(
//           alignment: Alignment.center,
//           children: [
//             if (comboMode)
//               Pulse(
//                 infinite: true,
//                 child: Container(
//                   height: 110,
//                   width: 12,
//                   decoration: BoxDecoration(
//                     color: Colors.orange.withOpacity(0.3),
//                     borderRadius: BorderRadius.circular(10),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.orange.withOpacity(0.5),
//                         blurRadius: 15,
//                         spreadRadius: 2,
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             AnimatedContainer(
//               duration: const Duration(milliseconds: 300),
//               height: 100,
//               width: 6,
//               decoration: BoxDecoration(
//                 color: Colors.white24,
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Stack(
//                 alignment: Alignment.bottomCenter,
//                 children: [
//                   AnimatedContainer(
//                     duration: const Duration(milliseconds: 500),
//                     height: (comboStreak.clamp(0, 20) / 20) * 100,
//                     width: 6,
//                     decoration: BoxDecoration(
//                       gradient: const LinearGradient(
//                         colors: [Colors.orange, Colors.redAccent],
//                         begin: Alignment.topCenter,
//                         end: Alignment.bottomCenter,
//                       ),
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 4),
//         Text(
//           "${comboStreak}x",
//           style: const TextStyle(
//             color: Colors.orange,
//             fontWeight: FontWeight.bold,
//             fontSize: 10,
//           ),
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       appBar: AppBar(
//         title: Text(
//           getAIName(),
//           style: const TextStyle(
//             fontWeight: FontWeight.bold,
//             color: Colors.white,
//           ),
//         ),
//         centerTitle: true,
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         flexibleSpace: ClipRect(
//           child: BackdropFilter(
//             filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//             child: Container(color: Colors.black.withOpacity(0.2)),
//           ),
//         ),
//         leading: IconButton(
//           icon: const Icon(
//             Icons.arrow_back_ios_new,
//             color: Colors.white,
//             size: 20,
//           ),
//           onPressed: () => Navigator.pop(context),
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.phone, color: Colors.white),
//             onPressed: _startCall,
//           ),
//         ],
//       ),
//       body: SafeArea(
//         child: Stack(
//           children: [
//             Positioned.fill(
//               child: Image.asset(widget.imagePath, fit: BoxFit.cover),
//             ),
//             Positioned.fill(
//               child: Container(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                     colors: [
//                       Colors.black.withOpacity(0.4),
//                       Colors.black.withOpacity(0.8),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//             Column(
//               children: [
//                 Expanded(
//                   child: AnimatedList(
//                     key: _listKey,
//                     controller: _scrollController,
//                     initialItemCount: messages.length,
//                     padding: const EdgeInsets.only(top: 100, bottom: 20),
//                     itemBuilder: (context, index, animation) =>
//                         _buildMessage(messages[index], animation),
//                   ),
//                 ),
//                 if (isSending) _typingBubble(),
//                 Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(30),
//                     child: BackdropFilter(
//                       filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 8),
//                         color: Colors.white.withOpacity(0.1),
//                         child: Row(
//                           children: [
//                             GestureDetector(
//                               onTap: _pickImage,
//                               child: const Icon(Icons.camera_alt, color: Colors.white),
//                             ),
//                             Expanded(
//                               child: TextField(
//                                 controller: _controller,
//                                 style: const TextStyle(color: Colors.white),
//                                 decoration: InputDecoration(
//                                   hintText: _isListening ? "Listening..." : "Talk your mind...",
//                                   hintStyle: TextStyle(
//                                     color: _isListening ? Colors.redAccent : Colors.white38,
//                                     fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
//                                   ),
//                                   border: InputBorder.none,
//                                   contentPadding: const EdgeInsets.symmetric(
//                                     horizontal: 20,
//                                     vertical: 15,
//                                   ),
//                                   suffixIcon: GestureDetector(
//                                     onLongPress: _startRecording,
//                                     onLongPressUp: _stopRecording,
//                                     child: Icon(
//                                       _isListening ? Icons.mic_off : Icons.mic,
//                                       color: _isListening ? Colors.redAccent : Colors.white,
//                                     ),
//                                   ),
//                                 ),
//                                 onSubmitted: (_) => _sendMessage(),
//                               ),
//                             ),
//                             IconButton(
//                               icon: Icon(
//                                 Icons.send_rounded,
//                                 color: isSending ? Colors.white24 : Colors.blueAccent,
//                               ),
//                               onPressed: isSending ? null : () => _sendMessage(),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             Positioned(top: 120, right: 16, child: _energyMeter()),
//             Align(
//               alignment: Alignment.topCenter,
//               child: ConfettiWidget(
//                 confettiController: _confettiController,
//                 blastDirectionality: BlastDirectionality.explosive,
//                 shouldLoop: false,
//                 colors: const [
//                   Colors.green,
//                   Colors.blue,
//                   Colors.pink,
//                   Colors.orange,
//                   Colors.purple,
//                 ],
//                 gravity: 0.1,
//                 numberOfParticles: 15,
//                 emissionFrequency: 0.05,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _TypingDot extends StatefulWidget {
//   final int delay;
//   const _TypingDot({this.delay = 0});

//   @override
//   State<_TypingDot> createState() => _TypingDotState();
// }

// class _TypingDotState extends State<_TypingDot> {
//   double _opacity = 0.2;

//   @override
//   void initState() {
//     super.initState();
//     _startAnimation();
//   }

//   void _startAnimation() async {
//     await Future.delayed(Duration(milliseconds: widget.delay));
//     while (mounted) {
//       if (mounted) setState(() => _opacity = 1.0);
//       await Future.delayed(const Duration(milliseconds: 600));
//       if (mounted) setState(() => _opacity = 0.2);
//       await Future.delayed(const Duration(milliseconds: 600));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedOpacity(
//       opacity: _opacity,
//       duration: const Duration(milliseconds: 600),
//       child: Container(
//         width: 6,
//         height: 6,
//         decoration: const BoxDecoration(
//           color: Colors.white70,
//           shape: BoxShape.circle,
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math';
import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loveable/RingingCallPage.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'call_screen.dart';
import 'secrets.dart';
import 'dart:typed_data';

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
  late ConfettiController _confettiController;
  late stt.SpeechToText _speech;
  
  bool _isListening = false;
  String _voiceBuffer = ""; // Private buffer for voice only

  final String apiKey = AppSecrets.appApiKey;

  List<({String role, String text, Uint8List? image})> messages = [];
  bool isSending = false;

  int comboStreak = 0;
  DateTime? lastMessageTime;
  bool comboMode = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _speech = stt.SpeechToText();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendInitialGreeting();
    });
  }

  void _sendInitialGreeting() {
    final firstGreeting = "Hey, hi! ... I'm ${getAIName()}, nice to meet you.";
    final secondGreeting =
        "So, what do I call you and what language would you like to chat with today, English or Pidgin?";

    setState(() {
      messages.add((role: "sympy", text: firstGreeting, image: null));
      _listKey.currentState?.insertItem(messages.length - 1);
      messages.add((role: "sympy", text: secondGreeting, image: null));
      _listKey.currentState?.insertItem(messages.length - 1);
    });
    _scrollToBottom();
  }

  String getAIName() => "Missy";

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

  // =================== SEND MESSAGE ===================
  Future<void> _sendMessage({String? text, Uint8List? image}) async {
    final messageText = text ?? _controller.text.trim();
    if (messageText.isEmpty && image == null) return;

    HapticFeedback.lightImpact();

    final lowerText = messageText.toLowerCase();
    if (lowerText.contains("call me") || lowerText.contains("lol")) {
       _confettiController.play();
       
       if (lowerText.contains("call me")) {
          final regex = RegExp(r"call me (?:as\s+)?(.+)", caseSensitive: false);
          final match = regex.firstMatch(messageText);
          
          String extractedName = "User";
          if (match != null && match.group(1) != null) {
            extractedName = match.group(1)!.trim();
            extractedName = extractedName.replaceAll(RegExp(r'[?.!]$'), '');
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

    if (image != null) {
      try {
        final response = await http.post(
          Uri.parse("https://web-production-6c359.up.railway.app/image_search"),
          headers: {
            "Content-Type": "application/octet-stream",
            "X-API-KEY": apiKey,
          },
          body: image,
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            messages.add((role: "sympy", text: data["reply"] ?? "", image: null));
            _listKey.currentState?.insertItem(messages.length - 1);
          });
        }
      } catch (e) {
        _handleError("Image search failed!");
      }
      _scrollToBottom();
      setState(() => isSending = false);
      return;
    }

    try {
      final contextData = messages
          .map((m) => {
                "role": m.role == "user" ? "user" : "assistant",
                "content": m.text,
              })
          .toList();

      final chatEndpoint =
          "https://web-production-6c359.up.railway.app/chat?voice=female&vibe=${widget.vibe}";

      final response = await http
          .post(
            Uri.parse(chatEndpoint),
            headers: {
              "Content-Type": "application/json",
              "X-API-KEY": apiKey,
            },
            body: jsonEncode({"message": messageText, "context": contextData}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String reply = data["reply"] ?? "I'm vibing, but I'm lost for words.";

        if (reply.toLowerCase().contains("haha") || reply.contains("😂")) {
          _confettiController.play();
        }

        setState(() {
          messages.add((role: "sympy", text: reply, image: null));
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
      messages.add((role: "sympy", text: errorText, image: null));
      _listKey.currentState?.insertItem(messages.length - 1);
    });
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
      image = await picker.pickImage(source: ImageSource.camera);
    } else if (choice == 'gallery') {
      image = await picker.pickImage(source: ImageSource.gallery);
    }

    if (image != null) {
      final bytes = await image.readAsBytes();
      _sendMessage(image: bytes);
    }
  }

  // =================== 2026 DIRECT SEND VOICE ===================
  void _startRecording() async {
    bool available = await _speech.initialize(
      onError: (val) => print('Engine Error: $val'),
      onStatus: (val) => print('Engine Status: $val'),
    );

    if (available) {
      HapticFeedback.heavyImpact();
      _voiceBuffer = ""; // Reset private buffer
      
      setState(() {
        _isListening = true;
      });

      await _speech.listen(
        onResult: (result) {
          // Store text privately, DON'T update the _controller.text
          _voiceBuffer = result.recognizedWords;
        },
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
      );
    }
  }

  void _stopRecording() async {
    HapticFeedback.mediumImpact();
    
    // Stop listening immediately
    await _speech.stop();
    setState(() => _isListening = false);

    // Give it 250ms to grab any final words from the buffer
    Future.delayed(const Duration(milliseconds: 250), () {
      if (_voiceBuffer.trim().isNotEmpty) {
        // Send directly to the AI
        _sendMessage(text: _voiceBuffer.trim());
        _voiceBuffer = ""; // Clear buffer
      }
    });
  }

  // =================== START CALL ===================
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
  Widget _kineticText(String text, bool isUser, [Uint8List? image]) {
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
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  image,
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                ),
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
      Animation<double> animation) {
    bool isUser = message.role == "user";
    return SizeTransition(
      sizeFactor: animation,
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: _kineticText(message.text, isUser, message.image),
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
                            GestureDetector(
                              onTap: _pickImage,
                              child: const Icon(Icons.camera_alt, color: Colors.white),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: _isListening ? "Listening..." : "Talk your mind...",
                                  hintStyle: TextStyle(
                                    color: _isListening ? Colors.redAccent : Colors.white38,
                                    fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
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
                                      color: _isListening ? Colors.redAccent : Colors.white,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.send_rounded,
                                color: isSending ? Colors.white24 : Colors.blueAccent,
                              ),
                              onPressed: isSending ? null : () => _sendMessage(),
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