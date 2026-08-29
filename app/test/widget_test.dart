import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:katha/main.dart';
import 'package:katha/screens/session_screen.dart';
import 'package:katha/services/content_service.dart';

/// Pumps a bounded number of frames instead of `pumpAndSettle`.
///
/// `pumpAndSettle` never returns while an indeterminate
/// `CircularProgressIndicator` is in the tree (its `AnimationController`
/// repeats forever, so a new frame is always scheduled) -- both loading
/// gates in `_AppRoot` show one while their Future is pending. A fixed
/// number of pumps lets those Futures resolve and the indicator get
/// replaced, without ever depending on "no more frames scheduled".
Future<void> pumpUntilLoaded(WidgetTester tester, {int times = 15}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    // Never let this suite depend on flutter_test's fake-HTTP-client
    // behavior for the CDN fetch -- go straight to the bundled asset.
    ContentService.debugSkipRemoteFetch = true;
  });

  tearDown(() {
    ContentService.debugSkipRemoteFetch = false;
  });

  testWidgets('Home screen shows title and unit decks', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const KathaApp());
    await pumpUntilLoaded(tester);

    expect(find.text('Katha'), findsOneWidget);
    expect(find.text('Greetings'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
  });

  testWidgets('Opening a unit starts a review session', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const KathaApp());
    await pumpUntilLoaded(tester);

    await tester.tap(find.text('Greetings'));
    await pumpUntilLoaded(tester, times: 5);

    // Exercise content is randomized (generator + shuffle), so this
    // checks the session screen loaded and is showing *an* exercise
    // rather than asserting specific card text.
    expect(find.byType(SessionScreen), findsOneWidget);
    expect(find.byType(ElevatedButton), findsWidgets);
  });
}
