import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/word.dart';

/// Wraps the platform text-to-speech engine for pronunciation playback.
///
/// This is the v1 audio source. [Word.audioAsset] is reserved for
/// native-speaker recordings — when a word has one set, the UI should
/// play that file instead of calling [speakWord], so recordings can be
/// swapped in per-word later with no change to this service's API.
///
/// Telugu voice availability is inconsistent across devices/browsers —
/// many desktop browsers ship no Telugu voice at all, and feeding Telugu
/// script to a voice that doesn't support it typically produces silence
/// rather than a mispronunciation. So this only uses [Word.scriptForTts]
/// when a Telugu voice is actually detected; otherwise it falls back to
/// the Latin transliteration, which any default voice can at least
/// attempt to sound out.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _teluguVoiceAvailable = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final languages = await _tts.getLanguages;
      if (languages is List) {
        _teluguVoiceAvailable = languages.any(
          (l) => l.toString().toLowerCase().startsWith('te'),
        );
      }
      debugPrint('TtsService: Telugu voice available = $_teluguVoiceAvailable (languages: $languages)');
      if (_teluguVoiceAvailable) {
        await _tts.setLanguage('te-IN');
      }
      await _tts.setSpeechRate(0.42);
      await _tts.setPitch(1.0);
    } catch (e) {
      debugPrint('TtsService: init failed, will fall back to transliteration. Error: $e');
    }
  }

  /// Speaks [word], preferring native Telugu script when a Telugu voice is
  /// available. Returns false if the TTS engine reported a failure, so the
  /// UI can tell the learner pronunciation isn't available right now
  /// instead of failing silently.
  Future<bool> speakWord(Word word) async {
    await _ensureInit();
    final text = _teluguVoiceAvailable ? word.ttsText : word.telugu;
    try {
      await _tts.stop();
      final result = await _tts.speak(text);
      // Most platforms return 1 for success; treat anything else as failure.
      return result == 1;
    } catch (e) {
      debugPrint('TtsService: speak("$text") failed: $e');
      return false;
    }
  }

  Future<void> stop() => _tts.stop();
}
