import 'package:flutter_test/flutter_test.dart';
import 'package:katha/services/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unit tests for CardState, the wrapper around the real `fsrs` package
/// (see progress_service.dart's class doc). These are the "evals" for
/// the scheduling logic itself: STRATEGY sec 7's whole premise -- that
/// review intervals grow on success and collapse on failure -- has to
/// hold or every downstream due-item calculation is wrong silently.
/// Assertions check direction and bounds rather than exact numbers,
/// since those come from FSRS's own (externally maintained) parameters.
void main() {
  group('CardState.applyReview', () {
    test('a new card starts due immediately (isNew, isDue)', () {
      final card = CardState(dueAt: DateTime.now());
      expect(card.isNew, isTrue);
      expect(card.isDue, isTrue);
    });

    test('rating again resets stability and schedules a near-term retry', () {
      final card = CardState(dueAt: DateTime.now(), stability: 20, reps: 3);
      card.applyReview(Rating.again);
      expect(card.stability, lessThan(20));
      expect(card.lapses, 1);
      expect(card.dueAt.difference(DateTime.now()).inHours, lessThan(1));
    });

    test('consecutive good ratings grow the interval', () {
      final card = CardState(dueAt: DateTime.now());
      final firstDue = () {
        card.applyReview(Rating.good);
        return card.dueAt;
      }();
      final secondDue = () {
        card.applyReview(Rating.good);
        return card.dueAt;
      }();
      expect(secondDue.difference(DateTime.now()), greaterThan(firstDue.difference(DateTime.now())));
    });

    test('easy grows the interval faster than good', () {
      final easyCard = CardState(dueAt: DateTime.now());
      final goodCard = CardState(dueAt: DateTime.now());
      easyCard.applyReview(Rating.easy);
      goodCard.applyReview(Rating.good);
      expect(easyCard.stability, greaterThan(goodCard.stability));
    });

    test('a lapse after growth leaves a positive but reduced stability', () {
      // Real FSRS's stability floor is 0.001, not the placeholder
      // scheduler's hardcoded 1.0 -- a card can legitimately end up
      // very fragile (due again within hours) after a lapse, which is
      // more accurate than artificially propping it back up to a full
      // day. This test checks the floor holds and the value dropped,
      // not a specific number -- see CardState class doc.
      final card = CardState(dueAt: DateTime.now(), stability: 1.2);
      card.applyReview(Rating.again);
      expect(card.stability, greaterThan(0));
      expect(card.stability, lessThan(1.2));
    });
  });

  group('ProgressService.dueLexemeIds', () {
    test('lexemes with no card yet are due', () async {
      final service = ProgressService();
      // Skip load() (needs SharedPreferences plugin binding) -- due-list
      // logic only touches in-memory state, which starts empty anyway.
      final due = service.dueLexemeIds(['a', 'b'], Dimension.recognition);
      expect(due, containsAll(['a', 'b']));
    });
  });

  group('ProgressService.weekMuggu', () {
    test('returns Monday..Sunday of the current week, 7 entries', () {
      final service = ProgressService();
      final week = service.weekMuggu();
      expect(week, hasLength(7));
      expect(week.first.date.weekday, DateTime.monday);
      expect(week.last.date.weekday, DateTime.sunday);
    });

    test('a day with no reviews yet is "today" if today, else "incomplete"', () {
      final service = ProgressService();
      final today = service.weekMuggu().firstWhere((d) => _isSameDay(d.date, DateTime.now()));
      expect(today.state, MugguDayState.today);
      expect(today.itemsReviewed, 0);
    });

    test('reaching the daily item goal marks today complete', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final service = ProgressService();
      for (var i = 0; i < ProgressService.dailyItemGoal; i++) {
        await service.recordReview('lex-\$i', Dimension.recognition, Rating.good);
      }
      final today = service.weekMuggu().firstWhere((d) => _isSameDay(d.date, DateTime.now()));
      expect(today.state, MugguDayState.complete);
      expect(today.itemsReviewed, ProgressService.dailyItemGoal);
    });

    test('days after today in the week are "future"', () {
      final service = ProgressService();
      final week = service.weekMuggu();
      final future = week.where((d) => d.date.isAfter(DateTime.now()));
      for (final d in future) {
        expect(d.state, MugguDayState.future);
      }
    });
  });
}

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
