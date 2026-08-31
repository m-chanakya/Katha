import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:katha/exercises/exercise.dart';
import 'package:katha/exercises/generator.dart';
import 'package:katha/exercises/session_provider.dart';
import 'package:katha/models/content.dart';
import 'package:katha/services/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for the teaching half of the course -- word-intro cards, concept
/// cards, and the hint system.
///
/// Two properties here are worth more than the rest and are asserted
/// several ways on purpose:
///
///  * **A hint must never be the answer.** A generator that offers the
///    script alongside four transliterations has turned an exercise into a
///    tap-through, and nothing else in the app would notice.
///  * **An introduction must be redeemed by a retrieval.** If teach cards
///    ever batch up at the front, Katha has quietly become the flashcard
///    app STRATEGY sec 10 rule 1 rules out.
ContentBundle _bundle() => ContentBundle.fromJson({
      'schemaVersion': 1,
      'contentVersion': 'test',
      'lexemes': [
        {'id': 'l1', 'translit': 'amma', 'script': 'అమ్మ', 'gloss': 'mother', 'pos': 'noun'},
        {'id': 'l2', 'translit': 'naanna', 'script': 'నాన్న', 'gloss': 'father', 'pos': 'noun'},
        {'id': 'l3', 'translit': 'akka', 'script': 'అక్క', 'gloss': 'elder sister', 'pos': 'noun'},
        {'id': 'l4', 'translit': 'anna', 'script': 'అన్న', 'gloss': 'elder brother', 'pos': 'noun'},
        {'id': 'l5', 'translit': 'chelli', 'script': 'చెల్లి', 'gloss': 'younger sister', 'pos': 'noun'},
      ],
      'concepts': [
        {
          'id': 'c1',
          'title': 'There is no word for brother',
          'description': 'Age is baked into the noun.',
          'bridge': {'hi': 'Hindi gives you भाई and lets you add बड़ा when it matters.'},
          'bridgeKind': 'new',
          'exampleSentenceIds': ['s1', 's2'],
          'unaudited': true,
        },
        {
          'id': 'c2',
          'title': 'Concept with no examples',
          'bridge': {'hi': 'x'},
          'bridgeKind': 'free',
          'exampleSentenceIds': <String>[],
        },
      ],
      'sentences': [
        {'id': 's1', 'translit': 'naa akka doctor', 'script': 'నా అక్క డాక్టర్', 'translation': 'my elder sister is a doctor', 'lexemeIds': ['l3']},
        {'id': 's2', 'translit': 'naa anna peru Ravi', 'translation': "my elder brother's name is Ravi", 'lexemeIds': ['l4']},
      ],
      'units': [
        {
          'id': 'u1',
          'title': 'Family',
          'lexemeIds': ['l1', 'l2', 'l3', 'l4', 'l5'],
          'conceptIds': ['c1', 'c2'],
        },
      ],
    });

Future<ProgressService> _progress() async {
  SharedPreferences.setMockInitialValues({});
  final p = ProgressService();
  await p.load();
  return p;
}

void main() {
  group('Concept model', () {
    test('parses bridge, bridgeKind and ordered example ids', () {
      final c = _bundle().conceptById['c1']!;
      expect(c.bridgeKind, 'new');
      expect(c.exampleSentenceIds, ['s1', 's2']);
      expect(c.bridgeFor('hi'), contains('भाई'));
      expect(c.bridgeFor('ta'), isNull, reason: 'unauthored L1s return null rather than the Hindi note');
      expect(c.unaudited, isTrue);
    });

    test('sentences carry optional script without breaking older content', () {
      final b = _bundle();
      expect(b.sentenceById['s1']!.script, 'నా అక్క డాక్టర్');
      expect(b.sentenceById['s2']!.script, isNull);
    });
  });

  group('WordIntroGenerator', () {
    test('teaches script, meaning, audio and up to two examples', () {
      final b = _bundle();
      final ex = WordIntroGenerator().generate(b.lexemeById['l3']!, b.sentencesByLexeme['l3']!);

      expect(ex.type, ExerciseType.wordIntro);
      expect(ex.isTeaching, isTrue);
      expect(ex.prompt, 'akka');
      expect(ex.script, 'అక్క');
      expect(ex.detail, 'elder sister');
      expect(ex.audioText, 'అక్క');
      expect(ex.audioTranslit, 'akka', reason: 'TTS needs a Latin fallback when no Telugu voice exists');
      expect(ex.examples.single.translation, 'my elder sister is a doctor');
    });
  });

  group('ConceptTeachGenerator', () {
    test('builds a card with examples, rule and bridge', () {
      final b = _bundle();
      final ex = ConceptTeachGenerator().generate(b.conceptById['c1']!, b)!;

      expect(ex.type, ExerciseType.conceptTeach);
      expect(ex.isTeaching, isTrue);
      expect(ex.conceptId, 'c1');
      expect(ex.bridgeKind, 'new');
      expect(ex.bridgeNote, isNotNull);
      expect(ex.examples.length, 2);
      expect(ex.lexemeIds, isEmpty, reason: 'a concept card grades nothing');
    });

    test('refuses to build a rule with no worked examples', () {
      final b = _bundle();
      // STRATEGY sec 10 rule 7 -- context before rule. A concept with
      // nothing to notice the pattern in is worse than no concept, so the
      // generator declines and validate_content.py errors on it.
      expect(ConceptTeachGenerator().generate(b.conceptById['c2']!, b), isNull);
    });
  });

  group('hints never reveal the answer', () {
    test('MCQ offers hints only when the options are glosses', () {
      final b = _bundle();
      final target = b.lexemeById['l1']!;
      final pool = b.lexemes;
      var sawTranslitDirection = false;
      var sawGlossDirection = false;

      // Direction is chosen by Random.nextBool() inside the generator, so
      // sweep seeds and assert the invariant for whichever came out.
      for (var seed = 0; seed < 40; seed++) {
        final ex = McqRecognitionGenerator().generate(target, pool, Random(seed))!;
        if (ex.correctAnswer == target.translit) {
          sawTranslitDirection = true;
          expect(ex.hints, isEmpty,
              reason: 'options are transliterations, so audio or script would point at the right button');
        } else {
          sawGlossDirection = true;
          expect(ex.hints.map((h) => h.kind), containsAll([HintKind.audio, HintKind.script]));
        }
      }
      expect(sawTranslitDirection && sawGlossDirection, isTrue, reason: 'both directions should occur');
    });

    test('audio-listen offers spelling, which does not give away the meaning', () {
      final b = _bundle();
      final ex = AudioListenGenerator().generate(b.lexemeById['l1']!, b.lexemes, Random(1))!;
      final kinds = ex.hints.map((h) => h.kind).toList();

      expect(kinds, containsAll([HintKind.translit, HintKind.script]));
      expect(kinds, isNot(contains(HintKind.meaning)), reason: 'the meaning is the answer here');
      expect(ex.hints.firstWhere((h) => h.kind == HintKind.translit).value, 'amma');
    });

    test('match rounds offer nothing, because every answer is already on screen', () {
      final b = _bundle();
      final ex = MatchPairsGenerator().generate(b.lexemes, Random(3))!;
      expect(ex.hints, isEmpty);
    });

    test('audio is the one free hint; the rest are penalizing', () {
      expect(HintKind.audio.isPenalizing, isFalse);
      expect(HintKind.script.isPenalizing, isTrue);
      expect(HintKind.translit.isPenalizing, isTrue);
      expect(HintKind.meaning.isPenalizing, isTrue);
    });
  });

  group('teaching cards in a session', () {
    test('a new word is introduced immediately before its first retrieval', () async {
      final b = _bundle();
      final progress = await _progress();
      final graded = [
        McqRecognitionGenerator().generate(b.lexemeById['l1']!, b.lexemes, Random(0))!,
        McqRecognitionGenerator().generate(b.lexemeById['l2']!, b.lexemes, Random(0))!,
      ];

      final withIntros = withWordIntros(graded: graded, content: b, progress: progress);

      expect(withIntros.length, 4);
      expect(withIntros[0].type, ExerciseType.wordIntro);
      expect(withIntros[0].lexemeIds, ['l1']);
      expect(withIntros[1].lexemeIds, ['l1'], reason: 'intro is adjacent to the item it introduces');
      expect(withIntros[2].type, ExerciseType.wordIntro);
      expect(withIntros[2].lexemeIds, ['l2']);
    });

    test('teach cards never batch: no two intros are adjacent', () async {
      final b = _bundle();
      final progress = await _progress();
      final graded = b.lexemes
          .map((l) => McqRecognitionGenerator().generate(l, b.lexemes, Random(0))!)
          .toList();

      final withIntros = withWordIntros(graded: graded, content: b, progress: progress);

      for (var i = 0; i < withIntros.length - 1; i++) {
        final backToBack = withIntros[i].type == ExerciseType.wordIntro &&
            withIntros[i + 1].type == ExerciseType.wordIntro;
        expect(backToBack, isFalse,
            reason: 'two intros in a row is the "here are 10 new words, tap next" screen');
      }
    });

    test('a word already in the schedule is not re-introduced', () async {
      final b = _bundle();
      final progress = await _progress();
      await progress.recordReview('l1', Dimension.recognition, Rating.good);

      final graded = [McqRecognitionGenerator().generate(b.lexemeById['l1']!, b.lexemes, Random(0))!];
      final withIntros = withWordIntros(graded: graded, content: b, progress: progress);

      expect(withIntros.length, 1);
      expect(withIntros.single.type, isNot(ExerciseType.wordIntro));
    });

    test('a multi-item match round introduces nothing', () async {
      final b = _bundle();
      final progress = await _progress();
      final graded = [MatchPairsGenerator().generate(b.lexemes, Random(3))!];

      final withIntros = withWordIntros(graded: graded, content: b, progress: progress);

      expect(withIntros.length, 1, reason: 'five intros back to back is exactly the batch to avoid');
    });

    test('one concept per lesson, and only until it has been taught', () async {
      final b = _bundle();
      final progress = await _progress();
      final unit = b.unitById['u1']!;

      final first = buildConceptCards(content: b, progress: progress, unit: unit);
      expect(first.length, 1, reason: 'STRATEGY sec 10 rule 8: one new concept per lesson');
      expect(first.single.conceptId, 'c1');

      await progress.markConceptSeen('c1');
      final second = buildConceptCards(content: b, progress: progress, unit: unit);
      // c2 has no examples, so the generator declines it -- the unit is
      // out of teachable concepts rather than repeating c1.
      expect(second, isEmpty);
    });

    test('a full session leads with the concept card and grades only the exercises', () async {
      final b = _bundle();
      final progress = await _progress();
      final session = buildSessionForUnit(content: b, progress: progress, unit: b.unitById['u1']!);

      expect(session.first.type, ExerciseType.conceptTeach);
      expect(session.where((e) => e.type == ExerciseType.wordIntro).length, 5,
          reason: 'all five lexemes are new');
      expect(session.where((e) => !e.isTeaching), isNotEmpty);
      // Match rounds are pushed last so their words have been met singly.
      final matchIndex = session.indexWhere((e) => e.type == ExerciseType.matchPairs);
      if (matchIndex >= 0) {
        expect(matchIndex, session.length - 1);
      }
    });
  });

  group('hints feed back into scheduling', () {
    test('a hinted correct answer is scheduled sooner than an unaided one', () async {
      final unaided = await _progress();
      await unaided.recordReview('l1', Dimension.recognition, Rating.good);

      final hinted = await _progress();
      await hinted.recordReview('l1', Dimension.recognition, Rating.good, hintsTaken: 1);

      expect(
        hinted.cardFor('l1', Dimension.recognition)!.dueAt.isBefore(
              unaided.cardFor('l1', Dimension.recognition)!.dueAt,
            ),
        isTrue,
        reason: 'correct-with-help is a weaker memory and must not look identical to FSRS',
      );
    });

    test('a hinted answer earns less XP, and a wrong one is not double-punished', () async {
      final hinted = await _progress();
      await hinted.recordReview('l1', Dimension.recognition, Rating.good, hintsTaken: 2);
      expect(hinted.totalXp, 5);

      final wrong = await _progress();
      await wrong.recordReview('l1', Dimension.recognition, Rating.again, hintsTaken: 2);
      expect(wrong.totalXp, 0);
      expect(wrong.cardFor('l1', Dimension.recognition)!.lapses, 1,
          reason: 'a hint should not turn one miss into two');
    });

    test('hint counts accumulate per (lexeme x dimension)', () async {
      final p = await _progress();
      await p.recordReview('l1', Dimension.recognition, Rating.good, hintsTaken: 2);
      await p.recordReview('l1', Dimension.listening, Rating.good, hintsTaken: 1);
      await p.recordReview('l2', Dimension.recognition, Rating.good);

      expect(p.hintsFor('l1', Dimension.recognition), 2);
      expect(p.hintsFor('l1', Dimension.listening), 1);
      expect(p.hintsFor('l2', Dimension.recognition), 0);
      expect(p.totalHintsTaken, 3);
      expect(p.mostHintedLexemes().first.key, 'l1');
      expect(p.mostHintedLexemes().length, 1, reason: 'items with no hints are not listed');
    });

    test('teaching state and hint counts survive a reload', () async {
      final p = await _progress();
      await p.recordReview('l1', Dimension.recognition, Rating.good, hintsTaken: 3);
      await p.markConceptSeen('c1');

      final reloaded = ProgressService();
      await reloaded.load();

      expect(reloaded.hintsFor('l1', Dimension.recognition), 3);
      expect(reloaded.hasSeenConcept('c1'), isTrue);
      expect(reloaded.hasSeenConcept('c2'), isFalse);
    });

    test('progress saved before hints existed still loads', () async {
      // Upgrade path: an older build's payload has no hintCounts or
      // seenConceptIds keys at all.
      SharedPreferences.setMockInitialValues({
        'katha_progress_v2': '{"streak":3,"totalXp":40,"lastStudyDate":null,"cards":{},"dailyReviewCounts":{}}',
      });
      final p = ProgressService();
      await p.load();

      expect(p.streak, 3);
      expect(p.totalXp, 40);
      expect(p.totalHintsTaken, 0);
      expect(p.hasSeenConcept('c1'), isFalse);
    });
  });
}
