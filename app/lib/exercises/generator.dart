import 'dart:math';

import '../models/content.dart';
import '../services/progress_service.dart' show Dimension;
import 'exercise.dart';

/// Turns content into concrete [Exercise]s. STRATEGY sec 6 lists 12
/// generators across phases; this is the Phase A slice plus the two
/// teaching generators.
///
/// **Hints are chosen here, not in the UI.** Only a generator knows which
/// direction it asked its question in, and therefore which reveals would
/// hand over the answer -- an MCQ showing four transliterations must not
/// offer "show the script" or "hear it", because either one points at the
/// right button, while the same generator asking the other direction can
/// safely offer both. The screen just renders whatever list it's given.
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

/// First meeting with a lexeme: what it looks like in both scripts, what it
/// means, how it sounds, and it used in a real sentence.
///
/// This is the card that was missing. Everything else in Katha asks the
/// learner to produce or recognise something; nothing introduced it. Not
/// graded, no XP, no FSRS write -- its entire job is to make the retrieval
/// that follows it fair.
class WordIntroGenerator {
  Exercise generate(Lexeme target, List<ExampleSentence> examples) => Exercise(
        type: ExerciseType.wordIntro,
        dimension: Dimension.recognition,
        lexemeIds: [target.id],
        prompt: target.translit,
        script: target.script,
        correctAnswer: target.gloss,
        detail: target.gloss,
        pronunciationTip: target.pronunciationTip,
        audioText: target.ttsText,
        audioTranslit: target.translit,
        examples: examples
            .take(2)
            .map((s) => TeachExample(translit: s.translit, script: s.script, translation: s.translation))
            .toList(),
      );
}

/// A grammar/pragmatics card: examples first, then the rule, then the
/// Hindi bridge (STRATEGY sec 4, sec 10 rule 7).
///
/// The ordering is the pedagogy -- showing the rule first turns a pattern
/// the learner could have noticed into a fact she has to memorise. The UI
/// keeps the bridge note behind a tap for the same reason.
class ConceptTeachGenerator {
  /// [bridgeLanguage] is the learner's L1 bridge; Hindi is the only one
  /// authored today (STRATEGY sec 1).
  Exercise? generate(Concept concept, ContentBundle content, {String bridgeLanguage = 'hi'}) {
    final examples = concept.exampleSentenceIds
        .map((id) => content.sentenceById[id])
        .whereType<ExampleSentence>()
        .map((s) => TeachExample(translit: s.translit, script: s.script, translation: s.translation))
        .toList();

    // A concept card with no worked examples is just a rule -- exactly the
    // thing STRATEGY sec 10 rule 7 rules out. Skip it rather than teach it
    // badly; validate_content.py warns so it gets authored, not lost.
    if (examples.isEmpty) return null;

    return Exercise(
      type: ExerciseType.conceptTeach,
      dimension: Dimension.recognition,
      lexemeIds: const [],
      conceptId: concept.id,
      title: concept.title,
      body: concept.description,
      bridgeNote: concept.bridgeFor(bridgeLanguage),
      bridgeKind: concept.bridgeKind,
      examples: examples,
    );
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
        // The meaning is the card's own reveal, so it isn't a hint here;
        // the script is extra help the learner can choose to take.
        hints: [
          if (target.script != null) Hint(HintKind.script, value: target.script),
        ],
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
      audioText: askForTranslit ? null : target.ttsText,
      audioTranslit: askForTranslit ? null : target.translit,
      // Direction matters. Gloss -> pick the Telugu: playing the audio or
      // showing the script identifies the correct option outright, so this
      // direction gets no hints at all. Telugu -> pick the meaning: both
      // are safe, because neither says which English gloss is right.
      hints: askForTranslit
          ? const []
          : [
              const Hint(HintKind.audio),
              if (target.script != null) Hint(HintKind.script, value: target.script),
            ],
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
      // Showing what was *said* is a real hint here (the exercise is "can
      // you decode this by ear"), but it still doesn't reveal which gloss
      // is correct -- so it downgrades the rating rather than being
      // withheld. This is the case the learner will reach for most: she
      // heard something, half-caught it, and wants to check the spelling
      // instead of guessing blind.
      hints: [
        Hint(HintKind.translit, value: target.translit),
        if (target.script != null) Hint(HintKind.script, value: target.script),
      ],
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
      // No hints: every transliteration and every gloss in the round is
      // already on screen, so any reveal would be the answer key.
      hints: const [],
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
