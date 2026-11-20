import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/article.dart';
import 'tts_service.dart';

/// The speech engine for this build, or null where audio is unsupported.
///
/// `AppBootstrap` supplies the `flutter_tts` implementation; tests and keyless
/// builds leave it null and the reader simply hides the Listen control.
final Provider<TtsService?> ttsServiceProvider = Provider<TtsService?>(
  (Ref ref) => null,
  name: 'ttsService',
);

/// Whether the reader is currently speaking this story.
final NotifierProvider<ArticleTtsController, bool> articleTtsProvider =
    NotifierProvider<ArticleTtsController, bool>(
      ArticleTtsController.new,
      name: 'articleTts',
    );

class ArticleTtsController extends Notifier<bool> {
  @override
  bool build() => false;

  TtsService? get _service {
    try {
      return ref.read(ttsServiceProvider);
    } catch (_) {
      return null;
    }
  }

  /// Starts listening, or stops when already speaking.
  Future<void> toggle(Article article) async {
    if (state) return stop();
    final TtsService? service = _service;
    if (service == null) return;
    final String text = ttsTextFor(article);
    if (text.trim().isEmpty) return;

    state = true;
    try {
      await service.speak(text);
    } catch (_) {
      state = false;
    }
  }

  Future<void> stop() async {
    state = false;
    try {
      await _service?.stop();
    } catch (_) {
      // A failing engine must not surface as a reader error.
    }
  }
}

/// Plain text handed to the engine: headline, summary and body without markup.
String ttsTextFor(Article article) {
  final String body = _plainText(article.bodyHtml);
  return <String>[
    article.title.trim(),
    article.summary.trim(),
    body,
  ].where((String part) => part.isNotEmpty).join('. ');
}

String _plainText(String html) {
  if (html.trim().isEmpty) return '';
  final String withoutTags = html
      .replaceAll(
        RegExp(r'<(script|style)[^>]*>.*?</\1>', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");
  return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
}
