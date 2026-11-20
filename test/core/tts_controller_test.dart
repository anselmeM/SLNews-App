import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/tts/tts_controller.dart';
import 'package:slnews_mobile/core/tts/tts_service.dart';

import '../support/fakes.dart';

class _FakeTts implements TtsService {
  final List<String> spoken = <String>[];
  int stops = 0;
  bool throwOnSpeak = false;

  @override
  Future<void> speak(String text) async {
    if (throwOnSpeak) throw StateError('engine unavailable');
    spoken.add(text);
  }

  @override
  Future<void> stop() async => stops++;
}

void main() {
  final Article article = Article(
    id: 'a',
    title: 'Leone Stars level with Guinea',
    summary: 'A late equaliser in the qualifier.',
    bodyHtml:
        '<p>Hello <b>world</b> &amp; friends.</p><script>track()</script>',
    publisher: testPublisher,
    publishedAt: DateTime.utc(2026, 11, 19),
  );

  late _FakeTts fake;
  late ProviderContainer container;

  setUp(() {
    fake = _FakeTts();
    container = ProviderContainer(
      overrides: <Override>[ttsServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
  });

  test('ttsTextFor strips markup and scripts', () {
    final String text = ttsTextFor(article);

    expect(text, contains('Leone Stars level with Guinea'));
    expect(text, contains('Hello world & friends.'));
    expect(text, isNot(contains('<')));
    expect(text, isNot(contains('track()')));
  });

  test('toggle speaks on, then stops on the second tap', () async {
    final ArticleTtsController controller = container.read(
      articleTtsProvider.notifier,
    );

    await controller.toggle(article);
    expect(container.read(articleTtsProvider), isTrue);
    expect(fake.spoken, hasLength(1));
    expect(fake.spoken.single, contains('Leone Stars'));

    await controller.toggle(article);
    expect(container.read(articleTtsProvider), isFalse);
    expect(fake.stops, 1);
  });

  test('a failing engine leaves the reader not-speaking', () async {
    fake.throwOnSpeak = true;
    final ArticleTtsController controller = container.read(
      articleTtsProvider.notifier,
    );

    await controller.toggle(article);

    expect(container.read(articleTtsProvider), isFalse);
  });

  test('a build without audio simply does nothing', () async {
    final ProviderContainer silent = ProviderContainer();
    addTearDown(silent.dispose);

    await silent.read(articleTtsProvider.notifier).toggle(article);

    expect(silent.read(articleTtsProvider), isFalse);
  });

  test('stop is safe when nothing is speaking', () async {
    await container.read(articleTtsProvider.notifier).stop();

    expect(container.read(articleTtsProvider), isFalse);
    expect(fake.stops, 1);
  });
}
