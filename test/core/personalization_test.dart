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
const Publisher _guardian = Publisher(
  id: 'guardian',
  name: 'The Guardian',
  wordmark: 'GUARDIAN',
  country: 'United Kingdom',
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

    final ReaderSignals readOnly = buildReaderSignals(
      knownArticles: <Article>[read, target],
      readIds: const <String>{'read'},
    );
    final ReaderSignals savedOnly = buildReaderSignals(
      knownArticles: <Article>[saved, target],
      savedIds: const <String>{'saved'},
    );
    expect(
      savedOnly.topicAffinity['business'],
      greaterThan(readOnly.topicAffinity['business'] ?? 0),
    );
  });

  test('a shared tag boosts a story outside its category', () {
    final Article read = _article(
      id: 'read',
      category: 'business',
      tags: const <String>['budget'],
    );
    final Article tagged = _article(
      id: 'tagged',
      category: 'world',
      tags: const <String>['budget'],
    );
    final Article untagged = _article(id: 'untagged', category: 'world');
    final ReaderSignals signals = buildReaderSignals(
      knownArticles: <Article>[read, tagged, untagged],
      readIds: const <String>{'read'},
    );

    expect(
      PersonalizationEngine.score(tagged, signals, now: now),
      greaterThan(PersonalizationEngine.score(untagged, signals, now: now)),
    );
  });

  test('persistent category affinity preserves current tag affinity', () {
    final Map<String, double> merged = mergeAffinityMaps(
      <String, double>{'politics': 2, 'freetown': 1.5},
      <String, double>{'politics': 3, 'budget': 2},
    );

    expect(merged['politics'], 5);
    expect(merged['freetown'], 1.5);
    expect(merged['budget'], 2);
  });

  test('duplicate known stories are counted once', () {
    final Article saved = _article(id: 'saved', category: 'business');
    final ReaderSignals signals = buildReaderSignals(
      knownArticles: <Article>[saved, saved, saved],
      savedIds: const <String>{'saved'},
    );

    expect(signals.topicAffinity['business'], 3);
  });

  test('team and league follow tags score sports stories', () {
    final Article teamStory = _article(
      id: 'team-story',
      category: 'sports',
      tags: const <String>['sports', 'team:lal', 'league:nba'],
    );
    final ReaderSignals signals = buildReaderSignals(
      knownArticles: <Article>[teamStory],
      followedIds: const <String>{'team:lal'},
    );

    expect(
      PersonalizationEngine.followMatch(teamStory, signals.followedIds),
      greaterThan(0),
    );
  });

  test('followed stories keep local coverage ahead of international', () {
    final Article local = _article(
      id: 'local',
      category: 'politics',
      publisher: _awoko,
      publishedAt: now.subtract(const Duration(hours: 6)),
    );
    final Article international = _article(
      id: 'international',
      category: 'politics',
      publisher: _bbc,
      publishedAt: now.subtract(const Duration(minutes: 5)),
    );
    final ReaderSignals signals = buildReaderSignals(
      knownArticles: <Article>[local, international],
      followedIds: const <String>{'topic:politics'},
    );

    final List<Article> followed = PersonalizationEngine.followedStories(
      <Article>[international, local],
      signals,
    );
    expect(followed.first.id, 'local');
  });

  test('exploration reserves a slot for a less-personalized story', () {
    final List<Article> ranked = <Article>[
      for (int i = 0; i < 8; i++)
        _article(id: 'politics$i', category: 'politics', publisher: _awoko),
      for (int i = 0; i < 4; i++)
        _article(id: 'business$i', category: 'business', publisher: _awoko),
    ];
    const ReaderSignals signals = ReaderSignals(
      topicAffinity: <String, double>{'politics': 10},
    );

    final List<Article> explored = PersonalizationEngine.reserveExploration(
      ranked,
      signals,
    );

    expect(explored, hasLength(ranked.length));
    expect(
      explored[PersonalizationEngine.explorationInterval - 1].categoryId,
      'business',
    );
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
    // All international: this test is about diversity caps, while the
    // local-first bucket ordering has its own test below.
    final List<Article> input = <Article>[
      for (int i = 0; i < 5; i++)
        _article(id: 'b$i', category: 'business', publisher: _bbc),
      for (int i = 0; i < 5; i++)
        _article(id: 'c$i', category: 'world', publisher: _reuters),
      for (int i = 0; i < 5; i++)
        _article(id: 'd$i', category: 'science', publisher: _ap),
      for (int i = 0; i < 5; i++)
        _article(id: 'e$i', category: 'health', publisher: _guardian),
    ];

    final List<Article> output = PersonalizationEngine.diversify(
      input,
      window: 8,
    );

    expect(output, hasLength(input.length));
    for (final String publisher in <String>[
      'bbc',
      'reuters',
      'ap',
      'guardian',
    ]) {
      expect(
        output.take(8).where((Article a) => a.publisher.id == publisher).length,
        lessThanOrEqualTo(PersonalizationEngine.maxPerPublisherInWindow),
        reason: publisher,
      );
    }
    expect(
      output.take(8).where((Article a) => a.categoryId == 'business').length,
      lessThanOrEqualTo(PersonalizationEngine.maxPerCategoryInWindow),
    );
  });

  test('diversity stops capping once the window is filled', () {
    final List<Article> input = <Article>[
      _article(id: 'p0', category: 'business', publisher: _bbc),
      _article(id: 'p1', category: 'business', publisher: _bbc),
      _article(id: 'p2', category: 'world', publisher: _reuters),
      _article(id: 'p3', category: 'health', publisher: _guardian),
      _article(id: 'p4', category: 'science', publisher: _ap),
      _article(id: 'p5', category: 'business', publisher: _bbc),
      _article(id: 'p6', category: 'culture', publisher: _guardian),
      _article(id: 'p7', category: 'education', publisher: _ap),
    ];

    final List<Article> output = PersonalizationEngine.diversify(
      input,
      window: 5,
    );

    // Past the fifth slot the ranked order must survive; old logic kept
    // applying caps to the whole bucket and could move p6 before p5.
    expect(output.map((Article a) => a.id).toList(), <String>[
      'p0',
      'p1',
      'p2',
      'p3',
      'p4',
      'p5',
      'p6',
      'p7',
    ]);
  });

  test('deferred local stories stay ahead of international stories', () {
    final List<Article> input = <Article>[
      for (int i = 0; i < 5; i++)
        _article(id: 'local$i', category: 'politics', publisher: _awoko),
      for (int i = 0; i < 5; i++)
        _article(id: 'world$i', category: 'business', publisher: _bbc),
    ];

    final List<Article> output = PersonalizationEngine.diversify(
      input,
      window: 4,
    );

    final int lastLocal = output.lastIndexWhere(
      (Article a) => a.publisher.id == 'awoko',
    );
    final int firstInternational = output.indexWhere(
      (Article a) => a.publisher.id == 'bbc',
    );
    expect(lastLocal, lessThan(firstInternational));
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
