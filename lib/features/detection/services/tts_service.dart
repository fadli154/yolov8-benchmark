import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Manages Flutter TTS lifecycle — speaks waste detection results.
///
/// Key guarantees:
///   • [stop] is always called before [speak] to prevent audio overlap.
///   • Cooldown prevents annoying repetition.
///   • [dispose] cleanly stops TTS before the page closes.
class DetectionTtsService {
  final FlutterTts _tts = FlutterTts();

  bool _isInitialized = false;
  bool _isDisposed = false;
  String _lastSpoken = '';
  int _lastSpokenTime = 0;

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> initialize({
    String language = 'id-ID',
    double speechRate = 0.4,
  }) async {
    if (_isInitialized) return;
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(speechRate);
    await _tts.setVolume(1.0);
    _isInitialized = true;
    debugPrint('[TtsService] Initialized.');
  }

  Future<void> setSpeechRate(double rate) async {
    if (_isDisposed) return;
    await _tts.setSpeechRate(rate);
  }

  /// Speak [text] if:
  ///   • It differs from the last spoken text, OR
  ///   • [cooldownMs] milliseconds have elapsed since last speech.
  Future<void> speak(String text, {int cooldownMs = 3000}) async {
    if (_isDisposed || text.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - _lastSpokenTime;

    if (text == _lastSpoken && elapsed < cooldownMs) return;

    try {
      await _tts.stop();
      await _tts.speak(text);
      _lastSpoken = text;
      _lastSpokenTime = now;
    } catch (e) {
      debugPrint('[TtsService] speak error: $e');
    }
  }

  Future<void> stop() async {
    if (_isDisposed) return;
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('[TtsService] stop error: $e');
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await stop();
    debugPrint('[TtsService] Disposed.');
  }
}
