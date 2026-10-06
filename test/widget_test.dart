import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ovie/voice_selection_screen.dart';

void main() {
  testWidgets('Ovie voice selection renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: VoiceSelectionScreen(),
      ),
    );

    expect(find.text('Choose your companion'), findsOneWidget);
    expect(find.text('Buddy'), findsOneWidget);
    expect(find.text('Missy'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);
  });

  testWidgets('Selecting a companion enables next step', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: VoiceSelectionScreen(),
      ),
    );

    await tester.tap(find.text('Buddy'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('NEXT'), findsOneWidget);
  });
}
