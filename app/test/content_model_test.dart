import 'package:flutter_test/flutter_test.dart';
import 'package:katha/models/content.dart';

/// Round-trip and lookup-index tests for the six-entity content model.
/// A malformed content bundle should fail loudly here in CI, not as a
/// runtime null-check crash on a learner's phone.
void main() {
  final sampleJson = {
    'schemaVersion': 1,
    'contentVersion': 'test',
    'lexemes': [
      {'id': 'l1', 'translit': 'namaskaram', 'script': 'నమస్కారం', 'gloss': 'hello', 'pos': 'interjection'},
      {'id': 'l2', 'translit': 'dhanyavaadamulu', 'gloss': 'thank you', 'pos': 'phrase', 'unaudited': true},
    ],
    'concepts': <Map<String, dynamic>>[],
    'sentences': [
      {'id': 's1', 'translit': 'namaskaram!', 'translation': 'hello!', 'lexemeIds': ['l1']},
    ],
    'units': [
      {'id': 'u1', 'title': 'Greetings', 'lexemeIds': ['l1', 'l2']},
    ],
  };

  test('parses required entities and builds lookup indexes', () {
    final bundle = ContentBundle.fromJson(sampleJson);

    expect(bundle.lexemes.length, 2);
    expect(bundle.lexemeById['l1']!.gloss, 'hello');
    expect(bundle.unitById['u1']!.title, 'Greetings');
    expect(bundle.sentencesByLexeme['l1']!.single.translation, 'hello!');
  });

  test('ttsText prefers script, falls back to translit', () {
    final bundle = ContentBundle.fromJson(sampleJson);
    expect(bundle.lexemeById['l1']!.ttsText, 'నమస్కారం');
    expect(bundle.lexemeById['l2']!.ttsText, 'dhanyavaadamulu');
  });

  test('optional entity arrays (forms/scenarios) default to empty, not a crash', () {
    final bundle = ContentBundle.fromJson(sampleJson);
    expect(bundle.forms, isEmpty);
    expect(bundle.scenarios, isEmpty);
  });
}
