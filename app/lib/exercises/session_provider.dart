import 'dart:math';

import '../models/content.dart';
import '../services/progress_service.dart';
import 'exercise.dart';
import 'generator.dart';

/// Assembles a session's exercise queue for one [Unit]: pulls due (and
/// new, up to a small cap) lexemes per STRATEGY sec 10 rule 5 ("5-7 new
/// items maximum"), across both implemented dimensions, hands them to
/// [buildSession] to turn into concrete exercises, and then threads the
/// *teaching* cards through the result.
///
/// This mixes recognition and listening items in one queue rather than
/// running them as separate modes -- STRATEGY sec 10 rule 3 ("interleave,
/// don't block"), applied to dimensions as well as lexemes.
///
/// ## Where teaching lands, and why
///
/// 1. **At most one concept card**, at the front. STRATEGY sec 10 rule 8:
///    "one new concept per lesson. Vocabulary can be plural; grammar
///    cannot." Concepts already seen are never re-taught unprompted.
/// 2. **A word-intro card immediately before that lexeme's first
///    retrieval** -- not batched into a preamble. Batching them would
///    rebuild exactly the "here are 10 new words, tap next" screen
///    STRATEGY sec 10 rule 1 bans; interleaving them means every
///    introduction is redeemed by a retrieval seconds later, which is
///    rule 6's expanding rehearsal starting from its first slot.
///
/// Teaching cards are added *after* [sessionCap] is applied, so the cap
/// stays a budget on how much the learner is asked to *answer*. A session
/// with six new words is longer in cards than one with none, but not
/// longer in questions -- which is the number that governs whether an
/// 8-item goal is honest.
List<Exercise> buildSessionForUnit({
  required ContentBundle content,
  required ProgressService progress,
  required Unit unit,
  int newItemCap = 6,
  int sessionCap = 12,
}) {
  final pool = unit.lexemeIds.map((id) => content.lexemeById[id]).whereType<Lexeme>().toList();
  final random = Random();

  final recognitionDue = progress.dueLexemeIds(unit.lexemeIds, Dimension.recognition);
  final listeningDue = progress.dueLexemeIds(unit.lexemeIds, Dimension.listening);

  // Cap brand-new (never-reviewed) items so a session never dumps the
  // whole unit on the learner at once.
  List<String> capNew(List<String> due, Dimension dim) {
    final newOnes = due.where((id) => progress.cardFor(id, dim) == null).toList();
    final seen = due.where((id) => progress.cardFor(id, dim) != null).toList();
    return [...seen, ...newOnes.take(newItemCap)];
  }

  final recognitionIds = capNew(recognitionDue, Dimension.recognition);
  final listeningIds = capNew(listeningDue, Dimension.listening);

  final recognitionLexemes = recognitionIds.map((id) => content.lexemeById[id]).whereType<Lexeme>().toList();
  final listeningLexemes = listeningIds.map((id) => content.lexemeById[id]).whereType<Lexeme>().toList();

  var graded = [
    ...buildSession(dueLexemes: recognitionLexemes, pool: pool, dimension: Dimension.recognition, random: random),
    ...buildSession(dueLexemes: listeningLexemes, pool: pool, dimension: Dimension.listening, random: random),
  ]..shuffle(random);

  if (graded.length > sessionCap) graded = graded.sublist(0, sessionCap);

  // Move any match-the-following round to the end. It covers five lexemes
  // at once, so if it landed early the shuffle could put it before those
  // words had been introduced individually -- which would either mean
  // five intro cards back to back (the batch this design exists to avoid)
  // or a matching game over words she has never seen. As a consolidation
  // round it also just works better last.
  final matchRounds = graded.where((e) => e.type == ExerciseType.matchPairs).toList();
  if (matchRounds.isNotEmpty) {
    graded = [...graded.where((e) => e.type != ExerciseType.matchPairs), ...matchRounds];
  }

  return [
    ...buildConceptCards(content: content, progress: progress, unit: unit),
    ...withWordIntros(graded: graded, content: content, progress: progress),
  ];
}

/// The unseen concepts attached to [unit], capped at one per session
/// (STRATEGY sec 10 rule 8). Returns empty once the learner has seen them
/// all, or when a concept has no authored examples to teach from.
///
/// Split out of [buildSessionForUnit] so a future "re-teach this concept"
/// entry point (the leech clinic in STRATEGY sec 7, or a browse mode) can
/// reuse it without going through session assembly.
List<Exercise> buildConceptCards({
  required ContentBundle content,
  required ProgressService progress,
  required Unit unit,
  int limit = 1,
}) {
  final generator = ConceptTeachGenerator();
  final cards = <Exercise>[];
  for (final id in unit.conceptIds) {
    if (cards.length >= limit) break;
    if (progress.hasSeenConcept(id)) continue;
    final concept = content.conceptById[id];
    if (concept == null) continue;
    final card = generator.generate(concept, content);
    if (card != null) cards.add(card);
  }
  return cards;
}

/// Inserts a [ExerciseType.wordIntro] immediately before the first graded
/// exercise that tests a lexeme the learner has never met.
///
/// "Never met" is read off the recognition card state rather than a
/// separate 'introduced' flag: a lexeme with no recognition card has, by
/// construction, never been through a session. That keeps this decision
/// derived from scheduling state instead of a second source of truth that
/// could drift out of sync with it.
///
/// A lexeme that's new only to the *listening* dimension gets no intro --
/// she's met the word, this is just the first time she's hearing it cold,
/// which is the exercise's whole point.
List<Exercise> withWordIntros({
  required List<Exercise> graded,
  required ContentBundle content,
  required ProgressService progress,
}) {
  final generator = WordIntroGenerator();
  final introduced = <String>{};
  final result = <Exercise>[];

  for (final exercise in graded) {
    // Only single-lexeme exercises trigger an introduction. A multi-item
    // round (match-the-following) would otherwise emit one intro card per
    // pair back to back; those lexemes get introduced by their own
    // individual exercises earlier in the queue instead, which is why
    // match rounds are sorted last.
    if (exercise.lexemeIds.length == 1) {
      final lexemeId = exercise.lexemeIds.single;
      if (introduced.add(lexemeId) && progress.cardFor(lexemeId, Dimension.recognition) == null) {
        final lexeme = content.lexemeById[lexemeId];
        if (lexeme != null) {
          result.add(generator.generate(lexeme, content.sentencesByLexeme[lexemeId] ?? const []));
        }
      }
    }
    result.add(exercise);
  }

  return result;
}
