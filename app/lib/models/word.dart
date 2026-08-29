/// A single example sentence built around a [Word], shown to give the
/// learner context beyond the bare translation.
class ExampleSentence {
  final String telugu; // transliterated Telugu, e.g. "nenu bagunnanu"
  final String english; // e.g. "I am fine"

  const ExampleSentence({required this.telugu, required this.english});
}

/// A single vocabulary item.
///
/// Script is intentionally not modelled yet — [telugu] is always a
/// transliteration in plain English letters. A dedicated script module
/// will introduce native Telugu script fields later without needing to
/// touch this model's other fields.
class Word {
  final String id;
  final String telugu;
  final String english;
  final String categoryId;
  final String partOfSpeech;

  /// Telugu script for this word, used ONLY to drive the TTS engine so it
  /// pronounces the word correctly — never shown in the UI. The script
  /// module (Phase 6) is what will actually teach these characters; until
  /// then this stays an internal implementation detail of pronunciation.
  final String? scriptForTts;

  /// Optional note on how to say a tricky sound, e.g. retroflex vs dental.
  final String? pronunciationTip;

  final List<ExampleSentence> examples;

  /// Path to a recorded-audio asset, when one exists. Null means "use TTS".
  /// This lets native-speaker recordings replace synthesized speech for
  /// individual words later with no change to the player code.
  final String? audioAsset;

  const Word({
    required this.id,
    required this.telugu,
    required this.english,
    required this.categoryId,
    required this.partOfSpeech,
    this.scriptForTts,
    this.pronunciationTip,
    this.examples = const [],
    this.audioAsset,
  });

  /// Best text to hand the TTS engine: Telugu script when we have it
  /// (much better pronunciation), falling back to the transliteration.
  String get ttsText => scriptForTts ?? telugu;
}

/// Metadata for a vocabulary category (a flashcard "deck").
class Category {
  final String id;
  final String label;
  final String emoji;

  const Category({required this.id, required this.label, required this.emoji});
}
