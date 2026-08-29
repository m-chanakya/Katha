import 'dart:math';

import '../models/content.dart';
import '../services/progress_service.dart';
import 'exercise.dart';
import 'generator.dart';

/// Assembles a session's exercise queue for one [Unit]: pulls due (and
/// new, up to a small cap) lexemes per STRATEGY sec 10 rule 5 ("5-7 new
/// items maximum"), across both implemented dimensions, and hands them
/// to [buildSession] to turn into concrete exercises.
///
/// This mixes recognition and listening items in one queue rather than
/// running them as separate modes -- STRATEGY sec 10 rule 3 ("interleave,
/// don't block"), applied to dimensions as well as lexemes.
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

  final exercises = [
    ...buildSession(dueLexemes: recognitionLexemes, pool: pool, dimension: Dimension.recognition, random: random),
    ...buildSession(dueLexemes: listeningLexemes, pool: pool, dimension: Dimension.listening, random: random),
  ]..shuffle(random);

  if (exercises.length > sessionCap) return exercises.sublist(0, sessionCap);
  return exercises;
}
