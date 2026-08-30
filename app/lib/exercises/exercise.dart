import '../services/progress_service.dart' show Dimension;

enum ExerciseType { recallFlip, mcqRecognition, audioListen, matchPairs }

/// One pairing shown in a [ExerciseType.matchPairs] round.
class MatchPair {
  final String lexemeId;
  final String left; // translit
  final String right; // gloss
  const MatchPair({required this.lexemeId, required this.left, required this.right});
}

/// A single runtime exercise, produced by a generator (STRATEGY sec 6:
/// "Exercise is deliberately NOT an entity" -- these are generated from
/// content, never authored or stored). One field set is shared across
/// types; type-specific fields are null when not applicable, which
/// keeps this a plain value object the UI can pattern-match on instead
/// of a class hierarchy the content pipeline would need to know about.
class Exercise {
  final ExerciseType type;
  final Dimension dimension;

  /// The lexeme(s) this exercise's review outcome should be recorded
  /// against. Single-item for flip/mcq/audio; all pairs for matchPairs.
  final List<String> lexemeIds;

  final String? prompt; // shown as the question
  final String? correctAnswer; // display text of the right answer
  final List<String>? options; // mcq/audioListen choices, includes correct, shuffled
  final String? audioText; // non-null => play this via TTS before/with the prompt (native script when available)
  final String? audioTranslit; // Latin transliteration to fall back to when no Telugu voice is available
  final String? detail; // recallFlip's "back of card" text (gloss + example)
  final List<MatchPair>? pairs; // matchPairs only

  const Exercise({
    required this.type,
    required this.dimension,
    required this.lexemeIds,
    this.prompt,
    this.correctAnswer,
    this.options,
    this.audioText,
    this.audioTranslit,
    this.detail,
    this.pairs,
  });
}
