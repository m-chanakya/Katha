import 'dart:math';

import '../models/content.dart';
import '../services/progress_service.dart' show Dimension;
import 'exercise.dart';

/// Turns due lexemes into concrete [Exercise]s. STRATEGY sec 6 lists 12
/// generators across phases; this is the Phase A slice (recallFlip
/// already existed, mcqRecognition and audioListen are new). Distractor
/// choice prefers a lexeme's authored confusion edges
/// ([Lexeme.confusionLexemeIds]) and falls back to random same-unit
/// lexemes until Phase B authors the real confusion graph.
abstract class ExerciseGenerator {
  Dimension get dimension;

  /// Returns null if there isn't enough pool (e.g. too few lexemes in
  /// the unit) to build a valid exercise -- callers should fall back to
  /// [RecallFlipGenerator], which never needs distractors.
  Exercise? generate(Lexeme target, List<Lexeme> pool, Random random);

  List<Lexeme> _pickDistractors(Lexeme target, List<Lexeme> pool, Random random, int count) {
    final byConfusion = pool.where((l) => target.confusionLexemeIds.contains(l.id)).toList();
    final rest = pool.where((l) => l.id != target.id && !byConfusion.contains(l)).toList()..shuffle(random);
    final picked = [...byConfusion, ...rest].where((l) => l.id != target.id).take(count).toList();
    return picked;
  }
}

class RecallFlipGenerator extends ExerciseGenerator {
  @override
  Dimension get dimension => Dimension.recognition;

  @override
  Exercise generate(Lexeme target, List<Lexeme> pool, Random random) => Exercise(
        type: ExerciseType.recallFlip,
        dimension: dimension,
        lexemeIds: [target.id],
        prompt: target.translit,
        correctAnswer: target.gloss,
        detail: target.gloss,
        audioText: target.ttsText,
        audioTranslit: target.translit,
      );
}

class McqRecognitionGenerator extends ExerciseGenerator {
  @override
  Dimension get dimension => Dimension.recognition;

  @override
  Exercise? generate(Lexeme target, List<Lexeme> pool, Random random) {
    final distractors = _pickDistractors(target, pool, random, 3);
    if (distractors.length < 3) return null;

    final askForTranslit = random.nextBool();
    final correct = askForTranslit ? target.translit : target.gloss;
    final options = [
      correct,
      ...distractors.map((d) => askForTranslit ? d.translit : d.gloss),
    ]..shuffle(random);

    return Exercise(
      type: ExerciseType.mcqRecognition,
      dimension: dimension,
      lexemeIds: [target.id],
      prompt: askForTranslit ? target.gloss : target.translit,
      correctAnswer: correct,
      options: options,
    );
  }
}

class AudioListenGenerator extends ExerciseGenerator {
  @override
  Dimension get dimension => Dimension.listening;

  @override
  Exercise? generate(Lexeme target, List<Lexeme> pool, Random random) {
    final distractors = _pickDistractors(target, pool, random, 3);
    if (distractors.length < 3) return null;

    final options = [target.gloss, ...distractors.map((d) => d.gloss)]..shuffle(random);

    return Exercise(
      type: ExerciseType.audioListen,
      dimension: dimension,
      lexemeIds: [target.id],
      prompt: 'What did you hear?',
      correctAnswer: target.gloss,
      options: options,
      audioText: target.ttsText,
      audioTranslit: target.translit,
    );
  }
}

class MatchPairsGenerator {
  Dimension get dimension => Dimension.recognition;

  /// Batch generator: builds one round covering up to [count] of
  /// [targets] at once, unlike the single-lexeme generators above.
  Exercise? generate(List<Lexeme> targets, Random random, {int count = 5}) {
    final chosen = (List.of(targets)..shuffle(random)).take(count).toList();
    if (chosen.length < 3) return null;
    return Exercise(
      type: ExerciseType.matchPairs,
      dimension: dimension,
      lexemeIds: chosen.map((l) => l.id).toList(),
      pairs: chosen.map((l) => MatchPair(lexemeId: l.id, left: l.translit, right: l.gloss)).toList(),
    );
  }
}

/// Builds a session queue for [dueLexemeIds] against [dimension], mixing
/// generators for variety and always falling back to [RecallFlipGenerator]
/// when a smarter generator can't get enough distractors (small unit,
/// first lexemes in a category, etc).
List<Exercise> buildSession({
  required List<Lexeme> dueLexemes,
  required List<Lexeme> pool,
  required Dimension dimension,
  required Random random,
}) {
  if (dueLexemes.isEmpty) return [];

  final generators = dimension == Dimension.listening
      ? [AudioListenGenerator()]
      : [McqRecognitionGenerator(), RecallFlipGenerator()];

  final exercises = <Exercise>[];
  for (final lexeme in dueLexemes) {
    Exercise? made;
    for (final g in generators) {
      made = g.generate(lexeme, pool, random);
      if (made != null) break;
    }
    exercises.add(made ?? RecallFlipGenerator().generate(lexeme, pool, random));
  }

  // Occasionally insert a match-the-following round covering several of
  // today's items together, when there's enough pool for it.
  if (dimension == Dimension.recognition && dueLexemes.length >= 3) {
    final match = MatchPairsGenerator().generate(dueLexemes, random);
    if (match != null) exercises.insert(min(3, exercises.length), match);
  }

  return exercises;
}
