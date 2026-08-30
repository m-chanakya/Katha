import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:katha/main.dart';
import 'package:katha/models/content.dart';
import 'package:katha/screens/session_screen.dart';
import 'package:katha/services/content_service.dart';

/// Loaded once (synchronously) for the whole suite. Deliberately reads
/// the real content/bundle.json via dart:io's *synchronous* File API,
/// not `rootBundle.loadString` -- see [ContentService.debugOverrideBundle]
/// for why the async/rootBundle path is unreliable inside a widget test.
final ContentBundle _testBundle = ContentBundle.fromJson(
  jsonDecode(File('assets/content/bundle.json').readAsStringSync()) as Map<String, dynamic>,
);

/// Pumps frames until [finder] finds something, instead of
/// `pumpAndSettle` (which never returns while an indeterminate
/// `CircularProgressIndicator` is in the tree -- both loading gates in
/// `_AppRoot` show one, and its `AnimationController` repeats forever,
/// so a new frame is always scheduled regardless of whether the
/// underlying Future has actually completed).
Future<void> pumpUntil(WidgetTester tester, Finder finder, {int maxPumps = 50}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    ContentService.debugOverrideBundle = _testBundle;
  });

  tearDown(() {
    ContentService.debugOverrideBundle = null;
  });

  testWidgets('Home screen shows title and unit decks', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const KathaApp());
    await pumpUntil(tester, find.text('Katha'));

    expect(find.text('Katha'), findsOneWidget);
    expect(find.text('Greetings'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
  });

  testWidgets('Opening a unit starts a review session', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const KathaApp());
    await pumpUntil(tester, find.text('Greetings'));

    await tester.tap(find.text('Greetings'));
    await pumpUntil(tester, find.byType(SessionScreen));

    // Exercise content is randomized (generator + shuffle), so this
    // checks the session screen loaded and is showing *an* exercise
    // rather than asserting specific card text.
    expect(find.byType(SessionScreen), findsOneWidget);
    // Exercise type varies (recallFlip / mcq / audioListen / matchPairs)
    // and each renders different interactive controls, so check for any
    // of the ones that show up before an answer is given, rather than
    // one specific widget type.
    expect(
      find.byWidgetPredicate((w) => w is ElevatedButton || w is OutlinedButton || w is IconButton),
      findsWidgets,
    );
  });
}
