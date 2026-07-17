import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speaks medication reminders aloud using the device's on-device
/// text-to-speech engine.
///
/// This is the automatic English spoken layer of a reminder. It never
/// throws to callers: if no TTS engine/voice is installed (common on some
/// Android devices), [speak] simply does nothing so the caregiver's
/// recorded voice note and the alarm tone still work.
class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;
  bool _available = false;

  /// Whether a usable TTS engine was found during [initialize].
  bool get isAvailable => _available;

  /// Configure the engine once, at app start (called from `main`).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // Block `speak` until the utterance finishes so the reminder loop can
      // sequence: alarm tone → spoken line → recording, without overlap.
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-US');
      // Slower + clearer for elderly listeners (Android/iOS scale 0.0–1.0).
      await _tts.setSpeechRate(0.42);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      _available = true;
      debugPrint('✅ TTS: Ready');
    } catch (e) {
      _available = false;
      debugPrint('❌ TTS: init failed — $e');
    }
  }

  /// Speak [text] and wait for it to finish. No-op when empty or when no
  /// engine is available.
  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (!_initialized) await initialize();
    if (!_available) return;

    try {
      await _tts.stop();
      await _tts.speak(trimmed);
    } catch (e) {
      debugPrint('❌ TTS: speak failed — $e');
    }
  }

  /// Immediately silence any in-progress speech. Safe to call anytime.
  Future<void> stop() async {
    if (!_initialized || !_available) return;
    try {
      await _tts.stop();
    } catch (_) {
      // Ignore — stopping a non-playing engine is harmless.
    }
  }
}
