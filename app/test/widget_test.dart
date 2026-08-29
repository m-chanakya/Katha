import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:katha/main.dart';
import 'package:katha/screens/session_screen.dart';
import 'package:katha/services/content_service.dart';

/// Pumps frames until [finder] finds something, instead of
/// `pumpAndSettle` or a fixed pump count.
///
/// `pumpAndSettle` never returns while an indeterminate
/// `CircularProgressIndicator` is in the tree (its `AnimationController`
/// repeats forever, so a new frame is always scheduled) -- both loading
/// gates in `_AppRoot` show one while their Future is pending. A *fixed*
/// pump count avoids that trap but turned out to be flaky the other
/// direction: how many pumps the content/prefs load actually needs
/// varies run to run (cold-start plugin registration, asset-bundle
/// warmup), so a count that's enough on one run can be too few on the
/// next. Polling for the widget we actually care about is robust to
/// both: it returns as soon as it can, and only fails for a real reason
/// once [maxPumps] is exhausted.
Future<void> pumpUntil(WidgetTester tester, Finder finder, {int maxPumps = 100}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  // Let the final `expect` below produce the real failure message
  // (found 0 widgets) rather than a generic "gave up polling" one.
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
    expect(find.byType(ElevatedButton), findsWidgets);
  });
}
