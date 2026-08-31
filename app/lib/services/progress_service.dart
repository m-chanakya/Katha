import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:shared_preferences/shared_preferences.dart';

/// The three review dimensions STRATEGY.md section 7 schedules
/// independently per lexeme: "schedule per (item x dimension), not per
/// item." Recognition and listening generators exist (Phase A);
/// production stays modelled but unused until coach mode ships in
/// Phase D (STRATEGY sec 1a.2, sec 8) -- nothing writes to it yet.
enum Dimension { recognition, listening, production }

/// The app's own rating vocabulary, kept separate from `package:fsrs`'s
/// [fsrs.Rating] so nothing outside this file needs to import the
/// scheduling package directly -- see [CardState._toFsrsRating].
enum Rating { again, hard, good, easy }

/// Spaced-repetition state for one (lexeme, dimension) pair, backed by
/// the real FSRS algorithm (https://pub.dev/packages/fsrs) via an
/// internal `fsrs.Card`. STRATEGY sec 7's "target ~90% retention" is
/// exactly the package's `Scheduler.desiredRetention` default, so
/// [_scheduler] below is unconfigured on purpose.
///
/// This replaces an earlier hand-written SM-2-style placeholder (see
/// CLAUDE.md's Phase A follow-up log for why swapping it in later was
/// deliberately made a localized change, not a data-model rewrite): the
/// public shape here -- [stability], [difficulty], [dueAt], [reps],
/// [lapses], [isNew], [isDue] -- is unchanged, only what computes the
/// next review date underneath it.
class CardState {
  fsrs.Card _card;
  int reps;
  int lapses;

  static int _cardIdSeq = 0;
  static int _nextCardId() => DateTime.now().millisecondsSinceEpoch * 1000 + (_cardIdSeq++ % 1000);

  /// Builds a card. With no arguments this is a brand-new, never
  /// reviewed card (FSRS "learning" state). Passing [stability] treats
  /// it as an established "review" state card instead -- mainly useful
  /// for tests that want to start from a specific point in a card's
  /// life rather than replaying reviews to get there.
  CardState({
    DateTime? dueAt,
    double? stability,
    double? difficulty,
    this.reps = 0,
    this.lapses = 0,
    DateTime? lastReviewedAt,
  }) : _card = fsrs.Card(
          cardId: _nextCardId(),
          state: stability != null ? fsrs.State.review : fsrs.State.learning,
          stability: stability,
          difficulty: difficulty ?? (stability != null ? 5.0 : null),
          due: (dueAt ?? DateTime.now()).toUtc(),
          lastReview: lastReviewedAt?.toUtc(),
        );

  CardState._fromCard(this._card, {this.reps = 0, this.lapses = 0});

  /// Shared across every card -- FSRS scheduling parameters are a
  /// property of the algorithm, not of an individual lexeme.
  static final fsrs.Scheduler _scheduler = fsrs.Scheduler();

  double get stability => _card.stability ?? 0.0;
  double get difficulty => _card.difficulty ?? 5.0;
  DateTime get dueAt => _card.due.toLocal();
  DateTime? get lastReviewedAt => _card.lastReview?.toLocal();

  bool get isDue => !_card.due.isAfter(DateTime.now().toUtc());
  bool get isNew => _card.lastReview == null;

  Map<String, dynamic> toJson() => {
        'card': _card.toMap(),
        'reps': reps,
        'lapses': lapses,
      };

  factory CardState.fromJson(Map<String, dynamic> j) {
    // Cards saved by the pre-FSRS placeholder scheduler don't have a
    // 'card' key -- rebuild an equivalent starting point from the old
    // flat fields instead of losing everyone's progress on upgrade.
    if (!j.containsKey('card')) {
      return CardState(
        dueAt: DateTime.parse(j['dueAt'] as String),
        stability: (j['stability'] as num).toDouble(),
        difficulty: (j['difficulty'] as num).toDouble(),
        reps: j['reps'] as int,
        lapses: j['lapses'] as int,
        lastReviewedAt: j['lastReviewedAt'] != null ? DateTime.parse(j['lastReviewedAt'] as String) : null,
      );
    }
    return CardState._fromCard(
      fsrs.Card.fromMap(j['card'] as Map<String, dynamic>),
      reps: j['reps'] as int? ?? 0,
      lapses: j['lapses'] as int? ?? 0,
    );
  }

  /// Applies one review outcome in place via the real FSRS scheduler.
  void applyReview(Rating rating) {
    reps += 1;
    if (rating == Rating.again) lapses += 1;
    final result = _scheduler.reviewCard(_card, _toFsrsRating(rating));
    _card = result.card;
  }

  static fsrs.Rating _toFsrsRating(Rating r) => switch (r) {
        Rating.again => fsrs.Rating.again,
        Rating.hard => fsrs.Rating.hard,
        Rating.good => fsrs.Rating.good,
        Rating.easy => fsrs.Rating.easy,
      };
}

/// Tracks per-(lexeme, dimension) review state plus session streak/XP,
/// persisted locally (no account/backend -- STRATEGY sec 1 infra
/// decision). Streak/XP carry forward unchanged from Phase 1; STRATEGY
/// sec 2 explicitly defers new gamification ("do not add games or XP to
/// the current flat word list [until Phase D]") so this session doesn't
/// expand that surface, only the scheduling underneath it.
class ProgressService extends ChangeNotifier {
  static const _prefsKey = 'katha_progress_v2';

  /// Items reviewed in a day counts that day toward the muggu (STRATEGY
  /// sec 8: "goal is items, not minutes... ~8 due items, set adaptively
  /// from the FSRS forecast"). Fixed for now rather than adaptive --
  /// the forecast-driven version is a real follow-up, not this pass.
  static const int dailyItemGoal = 8;

  /// How many days of review counts to retain -- only the current
  /// week's worth is ever displayed, but a little history costs
  /// nothing and leaves room for a monthly view later.
  static const int _dailyHistoryDays = 30;

  final Map<String, Map<Dimension, CardState>> _cards = {};
  // Keyed by 'yyyy-mm-dd' (local date) -> number of items reviewed
  // that day, which is what the muggu (weekly progress grid) reads.
  final Map<String, int> _dailyReviewCounts = {};
  int streak = 0;
  int totalXp = 0;
  DateTime? _lastStudyDate;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      streak = data['streak'] as int? ?? 0;
      totalXp = data['totalXp'] as int? ?? 0;
      final lastStudy = data['lastStudyDate'] as String?;
      _lastStudyDate = lastStudy != null ? DateTime.parse(lastStudy) : null;
      final cardsJson = data['cards'] as Map<String, dynamic>? ?? {};
      for (final entry in cardsJson.entries) {
        final perDimension = entry.value as Map<String, dynamic>;
        _cards[entry.key] = {
          for (final dEntry in perDimension.entries)
            Dimension.values.byName(dEntry.key): CardState.fromJson(dEntry.value as Map<String, dynamic>),
        };
      }
      final dailyJson = data['dailyReviewCounts'] as Map<String, dynamic>? ?? {};
      _dailyReviewCounts.addAll(dailyJson.map((k, v) => MapEntry(k, v as int)));
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'streak': streak,
      'totalXp': totalXp,
      'lastStudyDate': _lastStudyDate?.toIso8601String(),
      'cards': _cards.map((lexemeId, perDimension) => MapEntry(
            lexemeId,
            perDimension.map((dim, state) => MapEntry(dim.name, state.toJson())),
          )),
      'dailyReviewCounts': _dailyReviewCounts,
    };
    await prefs.setString(_prefsKey, jsonEncode(data));
  }

  CardState? cardFor(String lexemeId, Dimension dimension) => _cards[lexemeId]?[dimension];

  /// Lexemes (from [scope]) that are new or due for [dimension], sorted
  /// oldest-due first.
  List<String> dueLexemeIds(List<String> scope, Dimension dimension, {int? limit}) {
    final due = scope.where((id) {
      final card = _cards[id]?[dimension];
      return card == null || card.isDue;
    }).toList()
      ..sort((a, b) {
        final da = _cards[a]?[dimension]?.dueAt ?? DateTime(1970);
        final db = _cards[b]?[dimension]?.dueAt ?? DateTime(1970);
        return da.compareTo(db);
      });
    if (limit != null && due.length > limit) return due.sublist(0, limit);
    return due;
  }

  int knownCount(Dimension dimension, List<String> scope) => scope
      .where((id) => (_cards[id]?[dimension]?.stability ?? 0) >= 16)
      .length;

  int learningCount(Dimension dimension, List<String> scope) => scope
      .where((id) => _cards[id]?[dimension] != null && (_cards[id]![dimension]!.stability) < 16)
      .length;

  int newCount(Dimension dimension, List<String> scope) =>
      scope.where((id) => _cards[id]?[dimension] == null).length;

  Future<void> recordReview(String lexemeId, Dimension dimension, Rating rating) async {
    final perDimension = _cards.putIfAbsent(lexemeId, () => {});
    final card = perDimension.putIfAbsent(
      dimension,
      () => CardState(dueAt: DateTime.now()),
    );
    card.applyReview(rating);

    totalXp += switch (rating) {
      Rating.again => 0,
      Rating.hard => 5,
      Rating.good => 10,
      Rating.easy => 10,
    };
    _bumpStreakForToday();
    _bumpDailyReviewCount();
    _trimDailyReviewHistory();

    await _save();
    notifyListeners();
  }

  void _bumpStreakForToday() {
    final today = _dateOnly(DateTime.now());
    if (_lastStudyDate == null) {
      streak = 1;
    } else {
      final last = _dateOnly(_lastStudyDate!);
      final diff = today.difference(last).inDays;
      if (diff == 0) {
        // already studied today, streak unchanged
      } else if (diff == 1) {
        streak += 1;
      } else {
        streak = 1;
      }
    }
    _lastStudyDate = today;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dayKey(DateTime d) {
    final date = _dateOnly(d);
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _bumpDailyReviewCount() {
    final key = _dayKey(DateTime.now());
    _dailyReviewCounts[key] = (_dailyReviewCounts[key] ?? 0) + 1;
  }

  void _trimDailyReviewHistory() {
    if (_dailyReviewCounts.length <= _dailyHistoryDays) return;
    final cutoff = _dateOnly(DateTime.now()).subtract(const Duration(days: _dailyHistoryDays));
    _dailyReviewCounts.removeWhere((key, _) {
      final parts = key.split('-').map(int.parse).toList();
      return DateTime(parts[0], parts[1], parts[2]).isBefore(cutoff);
    });
  }

  /// This calendar week (Monday..Sunday) as muggu day states -- see
  /// BRANDING.md sec 7 "The streak, visualised": completing the day's
  /// item goal draws one more loop; a missed day leaves the muggu
  /// unfinished rather than destroying it; the week resets Monday.
  List<MugguDay> weekMuggu() {
    final today = _dateOnly(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final count = _dailyReviewCounts[_dayKey(day)] ?? 0;
      final MugguDayState state;
      if (day.isAfter(today)) {
        state = MugguDayState.future;
      } else if (day == today) {
        state = count >= dailyItemGoal ? MugguDayState.complete : MugguDayState.today;
      } else {
        state = count >= dailyItemGoal ? MugguDayState.complete : MugguDayState.incomplete;
      }
      return MugguDay(date: day, itemsReviewed: count, state: state);
    });
  }
}

/// One day's cell in the weekly muggu grid.
enum MugguDayState { complete, incomplete, today, future }

class MugguDay {
  final DateTime date;
  final int itemsReviewed;
  final MugguDayState state;

  const MugguDay({required this.date, required this.itemsReviewed, required this.state});

  double get progress => (itemsReviewed / ProgressService.dailyItemGoal).clamp(0.0, 1.0);
}
