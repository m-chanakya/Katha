import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word.dart';

/// A learner's Leitner-box state for one word.
///
/// Box 0 = just seen / got it wrong. Box 4 = "known", reviewed at the
/// longest interval. Getting a card right moves it up a box; getting it
/// wrong drops it back to box 0.
class WordProgress {
  final String wordId;
  int box;
  DateTime dueAt;
  int timesReviewed;

  WordProgress({
    required this.wordId,
    this.box = 0,
    required this.dueAt,
    this.timesReviewed = 0,
  });

  Map<String, dynamic> toJson() => {
        'wordId': wordId,
        'box': box,
        'dueAt': dueAt.toIso8601String(),
        'timesReviewed': timesReviewed,
      };

  factory WordProgress.fromJson(Map<String, dynamic> json) => WordProgress(
        wordId: json['wordId'] as String,
        box: json['box'] as int,
        dueAt: DateTime.parse(json['dueAt'] as String),
        timesReviewed: json['timesReviewed'] as int,
      );
}

/// Tracks per-word spaced-repetition state plus streaks and XP, all
/// persisted locally (no account/backend in v1).
class ProgressService extends ChangeNotifier {
  static const _boxIntervalsDays = [0, 1, 3, 7, 16];
  static const _prefsKey = 'katha_progress_v1';

  final Map<String, WordProgress> _progress = {};
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
      final wordsJson = data['words'] as Map<String, dynamic>? ?? {};
      for (final entry in wordsJson.entries) {
        _progress[entry.key] = WordProgress.fromJson(entry.value as Map<String, dynamic>);
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
      'words': _progress.map((key, value) => MapEntry(key, value.toJson())),
    };
    await prefs.setString(_prefsKey, jsonEncode(data));
  }

  WordProgress? progressFor(String wordId) => _progress[wordId];

  /// Words with no progress yet, or whose review is due today or earlier.
  List<Word> dueWords(List<Word> allWords) {
    final now = DateTime.now();
    return allWords.where((w) {
      final p = _progress[w.id];
      return p == null || !p.dueAt.isAfter(now);
    }).toList();
  }

  int knownCount(String? categoryId, List<Word> scope) =>
      scope.where((w) => (_progress[w.id]?.box ?? 0) >= _boxIntervalsDays.length - 1).length;

  int learningCount(List<Word> scope) => scope
      .where((w) => _progress.containsKey(w.id) && (_progress[w.id]!.box) < _boxIntervalsDays.length - 1)
      .length;

  int newCount(List<Word> scope) => scope.where((w) => !_progress.containsKey(w.id)).length;

  /// Call after the learner answers a flashcard. [knewIt] moves the word
  /// up a box (longer interval); missing it resets to box 0.
  Future<void> recordReview(String wordId, bool knewIt) async {
    final existing = _progress[wordId];
    final currentBox = existing?.box ?? 0;
    final nextBox = knewIt
        ? (currentBox + 1).clamp(0, _boxIntervalsDays.length - 1)
        : 0;
    final dueAt = DateTime.now().add(Duration(days: _boxIntervalsDays[nextBox]));

    _progress[wordId] = WordProgress(
      wordId: wordId,
      box: nextBox,
      dueAt: dueAt,
      timesReviewed: (existing?.timesReviewed ?? 0) + 1,
    );

    totalXp += knewIt ? 10 : 2;
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
