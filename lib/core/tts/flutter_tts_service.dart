import 'package:flutter_tts/flutter_tts.dart';

import 'tts_service.dart';

/// `flutter_tts` implementation of [TtsService].
///
/// Configured for English as spoken in Sierra Leone; rate is slowed slightly
/// from the platform default, which reads news copy too quickly.
class FlutterTtsService implements TtsService {
  FlutterTtsService([FlutterTts? engine]) : _engine = engine ?? FlutterTts();

  final FlutterTts _engine;
  Future<void>? _ready;

  Future<void> _configure() {
    return _ready ??= () async {
      await _engine.setLanguage('en-GB');
      await _engine.setSpeechRate(0.45);
      await _engine.setPitch(1);
      await _engine.awaitSpeakCompletion(false);
    }();
  }

  @override
  Future<void> speak(String text) async {
    await _configure();
    await _engine.stop();
    await _engine.speak(text);
  }

  @override
  Future<void> stop() async {
    await _configure();
    await _engine.stop();
  }
}
