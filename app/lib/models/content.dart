/// The six-entity content model from STRATEGY.md section 5, replacing the
/// flat Word/Category model from Phase 1.
///
/// This is a STRUCTURAL model: Form and Scenario exist so Phase C content
/// (inflected forms, situated dialogues) doesn't need another model
/// rewrite, but both arrays are empty until that content is authored.
/// Lexeme/Sentence/Unit are populated now via the Phase 1 migration
/// (scripts/migrate_word_bank.py) -- see CLAUDE.md "Content debt" for
/// what's still a placeholder (register tags, sentence tokenization).
library;

class Lexeme {
  final String id;
  final String translit;
  final String? script;
  final String gloss;
  final String pos;
  final String? legacyCategoryId;

  /// Formality/register axis (STRATEGY sec 1: nuvvu/meeru, -ra/-ndi).
  /// Null means "not yet audited by a native speaker" -- see
  /// [unaudited]. Do not treat null as "neutral".
  final String? register;
  final String? formalityLevel;
  final String dialect;
  final String? pronunciationTip;

  /// Maps a character id (or "default") to an audio source: either an
  /// asset path or the literal "tts" meaning "synthesize from [script]".
  final Map<String, String> audioVariants;
  final int? frequencyRank;

  /// Confusion-graph edges (STRATEGY sec 6) used by generators to pick
  /// distractors. Empty until Phase B authors the graph -- generators
  /// fall back to random distractors from the same unit until then.
  final List<String> confusionLexemeIds;

  /// True until a native speaker has reviewed register/formality/dialect
  /// for this item (STRATEGY sec 9's review queue). Drives the
  /// validate_content.py warning, not a blocking gate.
  final bool unaudited;

  const Lexeme({
    required this.id,
    required this.translit,
    this.script,
    required this.gloss,
    required this.pos,
    this.legacyCategoryId,
    this.register,
    this.formalityLevel,
    this.dialect = 'standard',
    this.pronunciationTip,
    this.audioVariants = const {},
    this.frequencyRank,
    this.confusionLexemeIds = const [],
    this.unaudited = false,
  });

  /// Best text to hand a TTS engine: native script when available.
  String get ttsText => script ?? translit;

  factory Lexeme.fromJson(Map<String, dynamic> j) => Lexeme(
        id: j['id'] as String,
        translit: j['translit'] as String,
        script: j['script'] as String?,
        gloss: j['gloss'] as String,
        pos: j['pos'] as String,
        legacyCategoryId: j['legacyCategoryId'] as String?,
        register: j['register'] as String?,
        formalityLevel: j['formalityLevel'] as String?,
        dialect: j['dialect'] as String? ?? 'standard',
        pronunciationTip: j['pronunciationTip'] as String?,
        audioVariants: (j['audioVariants'] as Map?)?.cast<String, String>() ?? const {},
        frequencyRank: j['frequencyRank'] as int?,
        confusionLexemeIds: (j['confusionLexemeIds'] as List?)?.cast<String>() ?? const [],
        unaudited: j['unaudited'] as bool? ?? false,
      );
}

/// An inflected surface form of a [Lexeme]. Not yet populated by any
/// content -- Phase C (verb conjugation, case endings) is what needs
/// this. Modelled now so that content is forward-compatible.
class LexemeForm {
  final String id;
  final String lexemeId;
  final String surfaceTranslit;
  final String? surfaceScript;
  final List<String> morphTags;
  final List<String> conceptIds;

  const LexemeForm({
    required this.id,
    required this.lexemeId,
    required this.surfaceTranslit,
    this.surfaceScript,
    this.morphTags = const [],
    this.conceptIds = const [],
  });

  factory LexemeForm.fromJson(Map<String, dynamic> j) => LexemeForm(
        id: j['id'] as String,
        lexemeId: j['lexemeId'] as String,
        surfaceTranslit: j['surfaceTranslit'] as String,
        surfaceScript: j['surfaceScript'] as String?,
        morphTags: (j['morphTags'] as List?)?.cast<String>() ?? const [],
        conceptIds: (j['conceptIds'] as List?)?.cast<String>() ?? const [],
      );
}

/// A teachable grammar/pragmatics point (STRATEGY sec 3) -- the unit of
/// *teaching*, as opposed to a Lexeme, which is a unit of vocabulary.
///
/// A first pass at these is hand-authored in `content/concepts.json` and
/// merged into the bundle by `scripts/migrate_word_bank.py`; Phase C
/// replaces them with concepts authored against the A-G section plan.
/// Everything currently in that file is `unaudited` -- drafted by Claude,
/// pending Achaarya's native-speaker review (STRATEGY sec 9).
class Concept {
  final String id;
  final String title;
  final String? description;
  final List<String> prerequisiteConceptIds;

  /// L1 bridge cards, e.g. {"hi": "..."} (STRATEGY sec 4).
  final Map<String, String> bridge;

  /// Which of STRATEGY sec 4's three flavours this bridge is:
  /// 'free' (Hindi already does this), 'twist' (looks familiar, behaves
  /// differently) or 'new' (no Hindi analog). Drives how the teaching UI
  /// frames the bridge note -- "you already have this" and "careful, this
  /// isn't what it looks like" are different pedagogical moves and
  /// shouldn't render identically.
  final String? bridgeKind;

  /// Example sentences to show *before* the explanation, in order.
  /// STRATEGY sec 10 rule 7: context before rule, 3-4 examples, then the
  /// bridge card. Ids resolve against [ContentBundle.sentenceById].
  final List<String> exampleSentenceIds;

  /// True until a native speaker has reviewed the explanation and bridge
  /// note. Same contract as [Lexeme.unaudited]: a warning in
  /// `validate_content.py`, not a blocking gate.
  final bool unaudited;

  const Concept({
    required this.id,
    required this.title,
    this.description,
    this.prerequisiteConceptIds = const [],
    this.bridge = const {},
    this.bridgeKind,
    this.exampleSentenceIds = const [],
    this.unaudited = false,
  });

  /// The bridge note for the learner's L1. Hindi is the only bridge
  /// authored today (STRATEGY sec 1: "Hindi, explicitly"), but the lookup
  /// goes through a language code so adding Marathi or Tamil stays a
  /// content task rather than a code change.
  String? bridgeFor(String languageCode) => bridge[languageCode];

  factory Concept.fromJson(Map<String, dynamic> j) => Concept(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        prerequisiteConceptIds: (j['prerequisiteConceptIds'] as List?)?.cast<String>() ?? const [],
        bridge: (j['bridge'] as Map?)?.cast<String, String>() ?? const {},
        bridgeKind: j['bridgeKind'] as String?,
        exampleSentenceIds: (j['exampleSentenceIds'] as List?)?.cast<String>() ?? const [],
        unaudited: j['unaudited'] as bool? ?? false,
      );
}

class ExampleSentence {
  final String id;
  final String translit;

  /// Native script for the whole sentence. Null for the migrated Phase 1
  /// sentences (word_bank.dart only carried script per word), so teaching
  /// cards fall back to showing transliteration alone rather than a
  /// half-rendered line.
  final String? script;
  final String translation;
  final List<String> lexemeIds;
  final String? characterId;
  final String? register;
  final String? scenarioId;
  final bool unaudited;

  const ExampleSentence({
    required this.id,
    required this.translit,
    this.script,
    required this.translation,
    this.lexemeIds = const [],
    this.characterId,
    this.register,
    this.scenarioId,
    this.unaudited = false,
  });

  factory ExampleSentence.fromJson(Map<String, dynamic> j) => ExampleSentence(
        id: j['id'] as String,
        translit: j['translit'] as String,
        script: j['script'] as String?,
        translation: j['translation'] as String,
        lexemeIds: (j['lexemeIds'] as List?)?.cast<String>() ?? const [],
        characterId: j['characterId'] as String?,
        register: j['register'] as String?,
        scenarioId: j['scenarioId'] as String?,
        unaudited: j['unaudited'] as bool? ?? false,
      );
}

/// A situated dialogue (STRATEGY sec 3/8: dinner table, market, ...).
/// Not yet populated -- no scenario content authored yet.
class Scenario {
  final String id;
  final String title;
  final List<String> sentenceIds;
  final String? description;

  const Scenario({
    required this.id,
    required this.title,
    this.sentenceIds = const [],
    this.description,
  });

  factory Scenario.fromJson(Map<String, dynamic> j) => Scenario(
        id: j['id'] as String,
        title: j['title'] as String,
        sentenceIds: (j['sentenceIds'] as List?)?.cast<String>() ?? const [],
        description: j['description'] as String?,
      );
}

/// A bundle of concepts + lexemes + sentences with declared
/// prerequisites -- a DAG node, not a list position (STRATEGY sec 5).
/// The 9 legacy category units are flat (no prerequisites) since they
/// predate the A-G course design in STRATEGY sec 3.
class Unit {
  final String id;
  final String title;
  final String? emoji;
  final String sectionId;
  final List<String> lexemeIds;
  final List<String> conceptIds;
  final List<String> prerequisiteUnitIds;

  const Unit({
    required this.id,
    required this.title,
    this.emoji,
    required this.sectionId,
    this.lexemeIds = const [],
    this.conceptIds = const [],
    this.prerequisiteUnitIds = const [],
  });

  factory Unit.fromJson(Map<String, dynamic> j) => Unit(
        id: j['id'] as String,
        title: j['title'] as String,
        emoji: j['emoji'] as String?,
        sectionId: j['sectionId'] as String? ?? 'legacy',
        lexemeIds: (j['lexemeIds'] as List?)?.cast<String>() ?? const [],
        conceptIds: (j['conceptIds'] as List?)?.cast<String>() ?? const [],
        prerequisiteUnitIds: (j['prerequisiteUnitIds'] as List?)?.cast<String>() ?? const [],
      );
}

/// The full content package fetched from the CDN (or loaded from the
/// bundled fallback asset). Indexed maps are built once for O(1) lookup.
class ContentBundle {
  final int schemaVersion;
  final String contentVersion;
  final List<Lexeme> lexemes;
  final List<LexemeForm> forms;
  final List<Concept> concepts;
  final List<ExampleSentence> sentences;
  final List<Scenario> scenarios;
  final List<Unit> units;

  late final Map<String, Lexeme> lexemeById = {for (final l in lexemes) l.id: l};
  late final Map<String, Unit> unitById = {for (final u in units) u.id: u};
  late final Map<String, Concept> conceptById = {for (final c in concepts) c.id: c};
  late final Map<String, ExampleSentence> sentenceById = {for (final s in sentences) s.id: s};
  late final Map<String, List<ExampleSentence>> sentencesByLexeme = () {
    final map = <String, List<ExampleSentence>>{};
    for (final s in sentences) {
      for (final lid in s.lexemeIds) {
        map.putIfAbsent(lid, () => []).add(s);
      }
    }
    return map;
  }();

  ContentBundle({
    required this.schemaVersion,
    required this.contentVersion,
    required this.lexemes,
    required this.forms,
    required this.concepts,
    required this.sentences,
    required this.scenarios,
    required this.units,
  });

  factory ContentBundle.fromJson(Map<String, dynamic> j) => ContentBundle(
        schemaVersion: j['schemaVersion'] as int,
        contentVersion: j['contentVersion'] as String,
        lexemes: (j['lexemes'] as List).map((e) => Lexeme.fromJson(e as Map<String, dynamic>)).toList(),
        forms: (j['forms'] as List? ?? []).map((e) => LexemeForm.fromJson(e as Map<String, dynamic>)).toList(),
        concepts: (j['concepts'] as List? ?? []).map((e) => Concept.fromJson(e as Map<String, dynamic>)).toList(),
        sentences: (j['sentences'] as List? ?? []).map((e) => ExampleSentence.fromJson(e as Map<String, dynamic>)).toList(),
        scenarios: (j['scenarios'] as List? ?? []).map((e) => Scenario.fromJson(e as Map<String, dynamic>)).toList(),
        units: (j['units'] as List).map((e) => Unit.fromJson(e as Map<String, dynamic>)).toList(),
      );

  /// Supported schema version this app build knows how to read. Bump
  /// alongside model changes; ContentService refuses newer/older major
  /// versions rather than rendering a partially-understood bundle.
  static const int currentSchemaVersion = 1;
}
