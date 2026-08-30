import 'package:flutter_test/flutter_test.dart';
import 'package:katha/services/progress_service.dart';

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
}
