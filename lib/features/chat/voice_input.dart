import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wrapper around speech_to_text that pipes partial results into a
/// callback. Returns true if listening started, false otherwise.
class VoiceInputService {
  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;
  bool _available = false;
  bool _busy = false;

  bool get isAvailable => _available;

  /// Initialize on first use. Idempotent.
  Future<bool> _ensureInit() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      _available = await _stt.initialize(
        onError: (e) {
          if (kDebugMode) print('STT error: ${e.errorMsg}');
        },
        onStatus: (s) {
          if (kDebugMode) print('STT status: $s');
        },
      );
    } catch (e) {
      _available = false;
    }
    return _available;
  }

  /// Start listening. Returns true if it actually started.
  /// [onPartial] is called with every partial result.
  /// [onFinal] is called when recognition finalizes.
  Future<bool> start(
    void Function(String text) onResult, {
    void Function(String text)? onPartial,
  }) async {
    if (_busy) return false;
    final ok = await _ensureInit();
    if (!ok) return false;

    _busy = true;
    await _stt.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult.call(result.recognizedWords);
        if (result.finalResult) {
          _busy = false;
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: onPartial != null,
      listenOptions: SpeechListenOptions(partialResults: onPartial != null),
    );
    return true;
  }

  Future<void> stop() async {
    if (!_busy) return;
    await _stt.stop();
    _busy = false;
  }

  void dispose() {
    _stt.cancel();
  }
}
