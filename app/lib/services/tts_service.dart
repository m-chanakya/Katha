import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Wraps the platform text-to-speech engine for pronunciation playback.
///
/// This is the fallback audio source. [Lexeme.audioVariants] is reserved
/// for native-speaker recordings — when a lexeme has one set, the UI
/// should play that file instead of calling [speak], so recordings can
/// be swapped in per-lexeme later with no change to this service's API.
///
/// Telugu voice availability is inconsistent across devices/browsers —
/// many desktop browsers ship no Telugu voice at all, and feeding Telugu
/// script to a voice that doesn't support it typically produces silence
/// rather than a mispronunciation. So this only uses a lexeme's Telugu
/// script when a Telugu voice is actually detected; otherwise it falls back to
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

  /// Speaks a lexeme, preferring [script] when a Telugu voice is
  /// available and falling back to [translit] otherwise. Returns false
  /// only if the engine actually threw — the success value some
  /// platforms return from `speak()` isn't consistent enough across
  /// web/iOS/Android to gate the UI on, so a thrown exception is the
  /// only signal treated as a real failure.
  Future<bool> speak({required String? script, required String translit}) async {
    await _ensureInit();
    final text = (_teluguVoiceAvailable && script != null) ? script : translit;
    try {
      await _tts.stop();
      await _tts.speak(text);
      return true;
    } catch (e) {
      debugPrint('TtsService: speak("$text") failed: $e');
      return false;
    }
  }

  Future<void> stop() => _tts.stop();
}
