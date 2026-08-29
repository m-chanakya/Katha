import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:katha/main.dart';
import 'package:katha/screens/session_screen.dart';

void main() {
  testWidgets('Home screen shows title and unit decks', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const KathaApp());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Katha'), findsOneWidget);
    expect(find.text('Greetings'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
  });

  testWidgets('Opening a unit starts a review session', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const KathaApp());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.text('Greetings'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Exercise content is randomized (generator + shuffle), so this
    // checks the session screen loaded and is showing *an* exercise
    // rather than asserting specific card text.
    expect(find.byType(SessionScreen), findsOneWidget);
    expect(find.byType(ElevatedButton), findsWidgets);
  });
}
