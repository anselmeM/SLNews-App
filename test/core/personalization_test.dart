import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/publisher.dart';
import 'package:slnews_mobile/core/domain/personalization.dart';


const Publisher _awoko = Publisher(
  id: 'awoko',
  name: 'Awoko',
  wordmark: 'AWOKO',
  country: 'Sierra Leone',
);
const Publisher _bbc = Publisher(
  id: 'bbc',
  name: 'BBC',
  wordmark: 'BBC',
  country: 'United Kingdom',
);
const Publisher _reuters = Publisher(
  id: 'reuters',
  name: 'Reuters',
  wordmark: 'REUTERS',
  country: 'United Kingdom',
);
const Publisher _ap = Publisher(
  id: 'ap',
  name: 'AP',
  wordmark: 'AP',
  country: 'United States',
);

Article _article({
  required String id,
  String category = 'politics',
  Publisher publisher = _awoko,
  List<String> tags = const <String>[],
  DateTime? publishedAt,
  bool breaking = false,
}) {
  return Article(
    id: id,
    title: 'Headline $id',
    publisher: publisher,
    publishedAt: publishedAt ?? DateTime(2026, 10, 15, 8),
    categoryId: category,
    tags: tags,
    isBreaking: breaking,
  );
}

void main() {
  final DateTime now = DateTime(2026, 10, 15, 12);

  test('empty signals are a no-op', () {
    const ReaderSignals empty = ReaderSignals();
    expect(empty.isEmpty, isTrue);
    expect(
      PersonalizationEngine.score(_article(id: 'a'), empty, now: now),
      isNot(0),
    );
  });

  test('explicit follows outweigh fresh unrelated stories', () {
    final Article followed = _article(
      id: 'followed',
      category: 'politics',
      publishedAt: now.subtract(const Duration(hours: 20)),
    );
    final Article unrelated = _article(
      id: 'unrelated',
      category: 'business',
      publishedAt: now.subtract(const Duration(hours: 1)),
    );
    final ReaderSignals signals = buildReaderSignals(
      knownArticles: <Article>[followed, unrelated],
      followedIds: const <String>{'topic:politics'},
    );

    expect(
      PersonalizationEngine.compare(followed, unrelated, signals, now: now),
      lessThan(0),
    );
  });

  test('reading history creates a topic affinity', () {
    final Article read = _article(id: 'read', category: 'business');
    final Article target = _article(id: 'target', category: 'business');
    final Article other = _article(id: 'other', category: 'sports');
    final ReaderSignals signals = buildReaderSignals(
      knownArticles: <Article>[read, target, other],
      readIds: const <String>{'read'},
    );

    expect(
      PersonalizationEngine.score(target, signals, now: now),
      greaterThan(PersonalizationEngine.score(other, signals, now: now)),
    );
  });

  test('saved stories weigh more than plain reads', () {
    final Article read = _article(id: 'read', category: 'business');
    final Article saved = _article(id: 'saved', category: 'business');
    final Article target = _article(id: 'target', category: 'business');
    final ReaderSignals signals = buildReaderSignals(
      knownArticles: <Article>[read, saved, target],
      readIds: const <String>{'read'},
      savedIds: const <String>{'saved'},
    );

    expect(signals.topicAffinity['business'], 4);
  });

  test('already-read stories are down-ranked unless saved or liked', () {
    final Article read = _article(id: 'read', category: 'business');
    final Article target = _article(id: 'target', category: 'business');
    final ReaderSignals signals = buildReaderSignals(
      knownArticles: <Article>[read, target],
      readIds: const <String>{'read'},
    );

    expect(
      PersonalizationEngine.score(read, signals, now: now),
      lessThan(PersonalizationEngine.score(target, signals, now: now)),
    );
  });

  test('breaking and fresh local stories get a bounded boost', () {
    final Article breaking = _article(
      id: 'breaking',
      category: 'top',
      breaking: true,
    );
    final Article ordinary = _article(id: 'ordinary', category: 'business');
    const ReaderSignals signals = ReaderSignals();

    expect(
      PersonalizationEngine.score(breaking, signals, now: now),
      greaterThan(PersonalizationEngine.score(ordinary, signals, now: now)),
    );
  });

  test(
    'followedStories only includes explicit matches and excludes sports',
    () {
      final Article politics = _article(id: 'politics', category: 'politics');
      final Article sports = _article(id: 'sports', category: 'sports');
      final Article business = _article(id: 'business', category: 'business');
      final ReaderSignals signals = buildReaderSignals(
        knownArticles: <Article>[politics, sports, business],
        followedIds: const <String>{'topic:politics', 'topic:sports'},
      );

      final List<Article> rail = PersonalizationEngine.followedStories(
        <Article>[politics, sports, business],
        signals,
        excludeIds: const <String>{'business'},
      );

      expect(rail.map((Article a) => a.id), <String>['politics']);
    },
  );

  test('followedStories respects the configured limit', () {
    final List<Article> stories = <Article>[
      for (int i = 0; i < 8; i++)
        _article(id: 'p$i', category: 'politics', publisher: _awoko),
    ];
    final ReaderSignals signals = buildReaderSignals(
      knownArticles: stories,
      followedIds: const <String>{'topic:politics'},
    );

    expect(
      PersonalizationEngine.followedStories(stories, signals, limit: 3),
      hasLength(3),
    );
  });

  test('diversify caps publishers and categories without dropping stories', () {
    final List<Article> input = <Article>[
      for (int i = 0; i < 5; i++)
        _article(id: 'a$i', category: 'politics', publisher: _awoko),
      for (int i = 0; i < 5; i++)
        _article(id: 'b$i', category: 'business', publisher: _bbc),
      for (int i = 0; i < 5; i++)
        _article(id: 'c$i', category: 'world', publisher: _reuters),
      for (int i = 0; i < 5; i++)
        _article(id: 'd$i', category: 'sports', publisher: _ap),
    ];

    final List<Article> output = PersonalizationEngine.diversify(
      input,
      window: 8,
    );

    expect(output, hasLength(input.length));
    expect(
      output.take(8).where((Article a) => a.publisher.id == 'awoko').length,
      lessThanOrEqualTo(PersonalizationEngine.maxPerPublisherInWindow),
    );
    expect(
      output.take(8).where((Article a) => a.categoryId == 'politics').length,
      lessThanOrEqualTo(PersonalizationEngine.maxPerCategoryInWindow),
    );
  });

  test('exploration is deterministic for the same day', () {
    final Article article = _article(id: 'stable');
    const ReaderSignals signals = ReaderSignals();

    expect(
      PersonalizationEngine.score(article, signals, now: now),
      PersonalizationEngine.score(article, signals, now: now),
    );
  });
}
