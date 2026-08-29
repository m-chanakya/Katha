import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The three review dimensions STRATEGY.md section 7 schedules
/// independently per lexeme: "schedule per (item x dimension), not per
/// item." Recognition and listening generators exist (Phase A);
/// production stays modelled but unused until coach mode ships in
/// Phase D (STRATEGY sec 1a.2, sec 8) -- nothing writes to it yet.
enum Dimension { recognition, listening, production }

enum Rating { again, hard, good, easy }

/// Spaced-repetition state for one (lexeme, dimension) pair.
///
/// NOTE: this is a deliberately simple SM-2-style scheduler, not the
/// real FSRS algorithm STRATEGY sec 7 specifies. Wiring up the actual
/// `fsrs` Dart package (https://pub.dev/packages/fsrs) needs `flutter
/// pub get` to inspect its real API, which this session's sandbox can't
/// run (no network from the device shell -- see CLAUDE.md). The
/// (lexeme x dimension) shape below is deliberately the shape FSRS
/// wants, so swapping the update function for a real FSRS call later is
/// a localized change, not a data-model rewrite.
class CardState {
  double stability; // roughly "days until ~90% recall"
  double difficulty; // 1 (easy) .. 10 (hard)
  DateTime dueAt;
  int reps;
  int lapses;
  DateTime? lastReviewedAt;

  CardState({
    this.stability = 1.0,
    this.difficulty = 5.0,
    required this.dueAt,
    this.reps = 0,
    this.lapses = 0,
    this.lastReviewedAt,
  });

  bool get isDue => !dueAt.isAfter(DateTime.now());
  bool get isNew => reps == 0;

  Map<String, dynamic> toJson() => {
        'stability': stability,
        'difficulty': difficulty,
        'dueAt': dueAt.toIso8601String(),
        'reps': reps,
        'lapses': lapses,
        'lastReviewedAt': lastReviewedAt?.toIso8601String(),
      };

  factory CardState.fromJson(Map<String, dynamic> j) => CardState(
        stability: (j['stability'] as num).toDouble(),
        difficulty: (j['difficulty'] as num).toDouble(),
        dueAt: DateTime.parse(j['dueAt'] as String),
        reps: j['reps'] as int,
        lapses: j['lapses'] as int,
        lastReviewedAt: j['lastReviewedAt'] != null ? DateTime.parse(j['lastReviewedAt'] as String) : null,
      );

  /// Applies one review outcome in place, producing the next interval.
  /// See class doc: SM-2-style placeholder for real FSRS.
  void applyReview(Rating rating) {
    final wasNew = isNew; // capture before bumping reps below
    reps += 1;
    lastReviewedAt = DateTime.now();

    if (rating == Rating.again) {
      lapses += 1;
      stability = max(1.0, stability * 0.5);
      difficulty = min(10.0, difficulty + 1.2);
      dueAt = DateTime.now().add(const Duration(minutes: 10));
      return;
    }

    final easeByRating = {Rating.hard: 1.2, Rating.good: 2.3, Rating.easy: 3.3}[rating]!;
    final difficultyAdjust = {Rating.hard: 0.15, Rating.good: -0.05, Rating.easy: -0.2}[rating]!;
    difficulty = (difficulty + difficultyAdjust).clamp(1.0, 10.0);

    // Harder items grow their interval more slowly.
    final difficultyDamping = 1.0 - (difficulty - 5.0) * 0.04;
    stability = max(1.0, stability * easeByRating * difficultyDamping);

    final intervalDays = wasNew ? 1 : stability;
    dueAt = DateTime.now().add(Duration(minutes: (intervalDays * 24 * 60).round()));
  }
}

/// Tracks per-(lexeme, dimension) review state plus session streak/XP,
/// persisted locally (no account/backend -- STRATEGY sec 1 infra
/// decision). Streak/XP carry forward unchanged from Phase 1; STRATEGY
/// sec 2 explicitly defers new gamification ("do not add games or XP to
/// the current flat word list [until Phase D]") so this session doesn't
/// expand that surface, only the scheduling underneath it.
class ProgressService extends ChangeNotifier {
  static const _prefsKey = 'katha_progress_v2';

  final Map<String, Map<Dimension, CardState>> _cards = {};
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
}
