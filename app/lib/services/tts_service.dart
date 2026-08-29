import 'package:flutter_tts/flutter_tts.dart';

/// Wraps the platform text-to-speech engine for pronunciation playback.
///
/// This is the v1 audio source. [Word.audioAsset] is reserved for
/// native-speaker recordings — when a word has one set, the UI should
/// play that file instead of calling [speak], so recordings can be
/// swapped in per-word later with no change to this service's API.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _tts.setLanguage('te-IN');
      await _tts.setSpeechRate(0.42);
      await _tts.setPitch(1.0);
    } catch (_) {
      // No Telugu voice on this platform/browser — speak() below will
      // still attempt playback with whatever default voice is available.
    }
  }

  Future<void> speak(String transliteratedText) async {
    await _ensureInit();
    try {
      await _tts.stop();
      await _tts.speak(transliteratedText);
    } catch (_) {
      // Swallowed: some platforms lack any Telugu voice. Once recordings
      // exist this failure becomes rare, and a fallback UI hint can be
      // added post-v1.
    }
  }

  Future<void> stop() => _tts.stop();
}
