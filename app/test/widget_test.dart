import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:katha/main.dart';

void main() {
  testWidgets('Home screen shows title and vocabulary decks', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const KathaApp());
    await tester.pumpAndSettle();

    expect(find.text('Katha'), findsOneWidget);
    expect(find.text('Greetings'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
  });

  testWidgets('Opening a deck shows a flashcard that flips on tap', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const KathaApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Greetings'));
    await tester.pumpAndSettle();

    expect(find.text('Hello'), findsOneWidget);

    await tester.tap(find.text('Hello'));
    await tester.pumpAndSettle();

    expect(find.text('Namaskaram'), findsOneWidget);
  });
}
