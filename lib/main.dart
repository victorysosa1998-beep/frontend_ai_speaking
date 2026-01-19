import 'package:flutter/material.dart';
import 'package:loveable/splashScreen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'voice_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.microphone.request();
  runApp(
     MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WelcomeScreen(),
    ),
  );
}
