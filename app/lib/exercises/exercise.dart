import '../services/progress_service.dart' show Dimension;

/// Exercise types split into two families:
///
/// * **Teaching** ([ExerciseType.wordIntro], [ExerciseType.conceptTeach]) --
///   the learner meets something for the first time. Nothing is graded and
///   no FSRS state is written. These exist because a course made only of
///   tests can measure what she knows but never gives her anything to know:
///   before this, a brand-new lexeme's first appearance in Katha was a
///   four-option quiz about a word she had never seen.
/// * **Graded** (everything else) -- retrieval practice, recorded against
///   [Dimension] state.
///
/// STRATEGY sec 10 rule 1 ("retrieval, never exposure") is not violated by
/// the teaching family, and reconciling the two is the whole design: a
/// teach card is never a standalone "here are 10 new words, tap next"
/// screen. [buildSessionForUnit] always places a wordIntro immediately
/// before that same lexeme's first retrieval in the same session, so
/// exposure and retrieval arrive as one beat (and rule 6's expanding
/// rehearsal starts at position 1 instead of position 0).
enum ExerciseType { recallFlip, mcqRecognition, audioListen, matchPairs, wordIntro, conceptTeach }

/// What a hint reveals. Katha shows meaning/spelling/audio on demand rather
/// than making the learner fail to find out -- STRATEGY sec 10 rule 2 wants
/// desirable difficulty, not a locked door.
///
/// Every tap is counted and fed back into scheduling (see
/// [ProgressService.recordReview]), so "I got it with help" and "I got it"
/// stop looking identical to FSRS. Hints are also the cheapest content-bug
/// detector in the app: a lexeme whose script hint gets tapped every single
/// time is telling you something the accuracy number cannot.
enum HintKind {
  /// Hear it. Deliberately **not** penalizing: Katha's learner has zero
  /// ambient Telugu (STRATEGY sec 1a.1), so audio exposure is the thing we
  /// most want to be free. Counted for analytics, never for scoring.
  audio,

  /// Show the Telugu script for the item.
  script,

  /// Show the Latin transliteration -- offered only when the answer isn't
  /// itself a transliteration.
  translit,

  /// Show the English gloss -- offered only when the answer isn't the gloss.
  meaning,
}

extension HintKindX on HintKind {
  /// Whether taking this hint should soften the review rating. Audio is
  /// free on purpose; see [HintKind.audio].
  bool get isPenalizing => this != HintKind.audio;

  String get label => switch (this) {
        HintKind.audio => 'Hear it',
        HintKind.script => 'Script',
        HintKind.translit => 'Spelling',
        HintKind.meaning => 'Meaning',
      };
}

/// One on-demand reveal attached to a graded exercise.
///
/// A generator only ever attaches hints that don't hand over the answer --
/// e.g. an MCQ whose options are transliterations offers neither the script
/// nor the audio, because either one identifies the right button. That
/// filtering lives in the generators (which know the question's direction),
/// not in the UI.
class Hint {
  final HintKind kind;

  /// Text revealed when tapped. Null for [HintKind.audio], whose effect is
  /// playback rather than a reveal.
  final String? value;

  const Hint(this.kind, {this.value});
}

/// One pairing shown in a [ExerciseType.matchPairs] round.
class MatchPair {
  final String lexemeId;
  final String left; // translit
  final String right; // gloss
  const MatchPair({required this.lexemeId, required this.left, required this.right});
}

/// One worked example on a teaching card: the sentence, and what it means.
/// STRATEGY sec 10 rule 7 -- context before rule, 3-4 examples *then* the
/// explanation.
class TeachExample {
  final String translit;
  final String? script;
  final String translation;

  const TeachExample({required this.translit, this.script, required this.translation});
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
  /// against. Single-item for flip/mcq/audio/wordIntro; all pairs for
  /// matchPairs; empty for conceptTeach.
  final List<String> lexemeIds;

  final String? prompt; // shown as the question, or the headword on a teach card
  final String? correctAnswer; // display text of the right answer
  final List<String>? options; // mcq/audioListen choices, includes correct, shuffled
  final String? audioText; // non-null => play this via TTS before/with the prompt (native script when available)
  final String? audioTranslit; // Latin transliteration to fall back to when no Telugu voice is available
  final String? detail; // recallFlip's "back of card" text (gloss + example)
  final List<MatchPair>? pairs; // matchPairs only

  /// On-demand reveals for a graded exercise. Empty when every possible
  /// hint would give the answer away (see [Hint]).
  final List<Hint> hints;

  // --- teaching fields (wordIntro / conceptTeach) ---

  /// Telugu script. Always shown while teaching -- transliteration stays
  /// the tested form (STRATEGY sec 1), but there's no cost to letting her
  /// see the writing system on a card she isn't being scored on, and it
  /// makes the Phase F script track a recognition problem rather than a
  /// cold start.
  final String? script;
  final String? pronunciationTip;

  /// conceptTeach only: the concept being taught, so the session can mark
  /// it seen and not re-teach it every visit.
  final String? conceptId;
  final String? title;
  final String? body;

  /// The L1 bridge note (STRATEGY sec 4), shown *after* the examples.
  final String? bridgeNote;

  /// 'free' | 'twist' | 'new' -- STRATEGY sec 4's three flavours, which
  /// the UI turns into the framing line ("you already do this in Hindi"
  /// vs "careful, this looks familiar and isn't").
  final String? bridgeKind;

  final List<TeachExample> examples;

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
    this.hints = const [],
    this.script,
    this.pronunciationTip,
    this.conceptId,
    this.title,
    this.body,
    this.bridgeNote,
    this.bridgeKind,
    this.examples = const [],
  });

  /// True for cards that teach rather than test. These record no review,
  /// earn no XP and don't count toward the daily item goal -- STRATEGY
  /// sec 8 is explicit that XP rewards learning, not time spent, and a
  /// tap-through card is time.
  bool get isTeaching => type == ExerciseType.wordIntro || type == ExerciseType.conceptTeach;
}
