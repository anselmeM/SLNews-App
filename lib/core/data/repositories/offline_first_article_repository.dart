import 'dart:async';

import '../../domain/models/article.dart';
import '../../domain/repositories/article_repository.dart';
import '../local/article_cache.dart';
import '../seed/seed_data.dart';
import '../seed/seed_loader.dart';
import '../sources/api_client.dart';
import '../sources/feed_source.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

/// Editorial content resolved in-memory → disk cache → bundled seed → network.
///
/// Every read is answered from local state first and only touches the network
/// when nothing local exists, so a reader with no connectivity still gets a
/// full feed and [refresh] failures are invisible to the UI.
class OfflineFirstArticleRepository implements ArticleRepository {
  /// Creates a repository over [sources], [cache] and [seedLoader].
  ///
  /// [client] is reserved for a future aggregated endpoint: today the sources
  /// carry their own client, and [cacheTtl] decides how long a cached category
  /// answer is trusted before matching sources are consulted again.
  OfflineFirstArticleRepository({
    required List<FeedSource> sources,
    required ArticleCache cache,
    required SeedLoader seedLoader,
    ApiClient? client,
    Duration cacheTtl = const Duration(minutes: 10),
    Future<Article?> Function(String id)? fetchById,
  }) : _sources = List<FeedSource>.unmodifiable(sources),
       _articleCache = cache,
       _seeds = seedLoader,
       _ttl = cacheTtl,
       // Private field, so the named parameter cannot be an initializing formal.
       // ignore: prefer_initializing_formals
       _fetchById = fetchById;

  /// Cache key holding the merged feed from the last successful refresh.
  static const String allCacheKey = 'all';

  /// Per-source budget; a slow outlet must not hold the whole refresh open.
  static const Duration sourceTimeout = Duration(seconds: 8);

  /// Stories requested from each source before de-duplication.
  static const int perSourceLimit = 40;

  final List<FeedSource> _sources;
  final ArticleCache _articleCache;

  /// Optional single-story endpoint for deep links outside the feed (B4).
  final Future<Article?> Function(String id)? _fetchById;
  final SeedLoader _seeds;
  final Duration _ttl;

  List<Article> _memory = <Article>[];
  List<Article>? _seedArticles;
  bool _hydrated = false;
  // Optimistic: a fresh launch with connectivity must not flash an "Offline"
  // banner before the first refresh has even been attempted. Only a failed
  // refresh flips this on.
  bool _offline = false;
  DateTime? _lastSyncedAt;
  Future<List<Article>>? _inFlightRefresh;

  @override
  bool get isOffline => _offline;

  @override
  DateTime? get lastSyncedAt => _lastSyncedAt;

  @override
  Future<List<Article>> topStories({int limit = 8}) async {
    final List<Article> articles = await _resolve();
    final List<Article> ordered = _sortDescending(articles);

    final List<Article> flagged = <Article>[
      for (final Article article in ordered)
        if (article.isBreaking || article.isLive) article,
    ];
    if (flagged.isEmpty) return _cap(ordered, limit);

    // Flagged stories lead the carousel; the latest of the rest fill it out so
    // the hero strip is never half empty.
    final List<Article> rest = <Article>[
      for (final Article article in ordered)
        if (!article.isBreaking && !article.isLive) article,
    ];
    return _cap(<Article>[...flagged, ...rest], limit);
  }

  @override
  Future<List<Article>> byCategory(String categoryId, {int limit = 30}) async {
    await _hydrate();

    final List<Article> cached = _filter(_memory, categoryId);
    if (cached.isNotEmpty && _articleCacheIsFresh) return _cap(cached, limit);

    final List<FeedSource> matching = <FeedSource>[
      for (final FeedSource source in _sources)
        if (source.config.categoryId == categoryId) source,
    ];
    if (matching.isNotEmpty) {
      final List<Article> fetched = await _collect(matching);
      if (fetched.isNotEmpty) {
        final List<Article> merged = _merge(_memory, fetched);
        _memory = merged;
        await _articleCache.write(allCacheKey, merged);
        final List<Article> result = _filter(merged, categoryId);
        if (result.isNotEmpty) return _cap(result, limit);
      }
    }

    if (cached.isNotEmpty) return _cap(cached, limit);

    final List<Article> seeded = _sortDescending(
      _filter(await _seed(), categoryId),
    );
    if (seeded.isNotEmpty) return _cap(seeded, limit);

    // A category with no seeded stories still has to render something.
    final List<Article> fallback = _memory.isNotEmpty ? _memory : await _seed();
    return _cap(_sortDescending(fallback), limit);
  }

  @override
  Future<Article?> byId(String id) async {
    for (final Article article in await _resolve()) {
      if (article.id == id) return article;
    }
    // A deep link can name a seeded story that is no longer in the merged feed.
    for (final Article article in await _seed()) {
      if (article.id == id) return article;
    }
    // Last resort: fetch that one story and cache it, so the next offline open
    // of the same deep link has a body to read.
    final Future<Article?> Function(String id)? fetcher = _fetchById;
    if (fetcher != null) {
      try {
        final Article? fetched = await fetcher(id).timeout(sourceTimeout);
        if (fetched != null) {
          final List<Article> merged = _merge(_memory, <Article>[fetched]);
          _memory = merged;
          await _articleCache.write(allCacheKey, merged);
          return fetched;
        }
      } catch (error) {
        AppLog.debug(
          'OfflineFirstArticleRepository: byId fetch failed for "$id": $error',
        );
      }
    }
    return null;
  }

  @override
  Future<List<Article>> search(String query, {int limit = 20}) async {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const <Article>[];

    // One result per story, from both the live/cached resolution and the bundled
    // seed. The seed used to be consulted only when the network produced no hit,
    // so a single cached match hid every seeded match for the same query.
    final Map<String, Article> candidates = <String, Article>{};
    for (final Article article in await _resolve()) {
      candidates.putIfAbsent(article.id, () => article);
    }
    for (final Article article in await _seed()) {
      candidates.putIfAbsent(article.id, () => article);
    }

    final List<({Article article, int score})> scored =
        <({Article article, int score})>[
          for (final Article article in candidates.values)
            if (_score(article, needle) > 0)
              (article: article, score: _score(article, needle)),
        ];
    scored.sort((
      ({Article article, int score}) a,
      ({Article article, int score}) b,
    ) {
      if (a.score != b.score) return b.score.compareTo(a.score);
      return b.article.publishedAt.compareTo(a.article.publishedAt);
    });
    return _cap(
      scored.map((({Article article, int score}) hit) => hit.article).toList(),
      limit,
    );
  }

  /// Relevance of [article] for [needle], weighted by where the match is.
  ///
  /// A headline match beats a tag match, which beats the body: the old search
  /// treated every field equally, so a story that mentioned the word once in its
  /// body could outrank one whose headline was about it (only recency decided,
  /// and only among equal fields).
  static int _score(Article article, String needle) {
    final String title = article.title.toLowerCase();
    int score = 0;
    if (title == needle) {
      score += 100;
    } else if (title.startsWith(needle)) {
      score += 40;
    } else if (title.contains(needle)) {
      score += 30;
    }
    if (article.categoryId.toLowerCase() == needle) score += 20;
    for (final String tag in article.tags) {
      if (tag.toLowerCase().contains(needle)) {
        score += 15;
        break;
      }
    }
    if (article.publisher.name.toLowerCase().contains(needle)) score += 12;
    if (article.summary.toLowerCase().contains(needle)) score += 8;
    if (article.bodyHtml.toLowerCase().contains(needle)) score += 4;
    return score;
  }

  @override
  Future<List<Article>> refresh() {
    final Future<List<Article>>? inFlight = _inFlightRefresh;
    if (inFlight != null) return inFlight;

    final Future<List<Article>> started = _refresh();
    _inFlightRefresh = started;
    return started.whenComplete(() => _inFlightRefresh = null);
  }

  bool get _articleCacheIsFresh {
    final DateTime? synced = _lastSyncedAt;
    if (synced == null) return false;
    return DateTime.now().difference(synced) < _ttl;
  }

  Future<List<Article>> _refresh() async {
    await _hydrate();
    if (_sources.isEmpty) return _memory;

    final List<Article> fetched = await _collect(_sources);
    if (fetched.isEmpty) {
      // Total network failure: keep serving whatever is local, and report the
      // cache/seed fallback through `isOffline`.
      _offline = true;
      if (_memory.isEmpty) _memory = await _seed();
      return _memory;
    }

    final List<Article> merged = _merge(_memory, fetched);
    _memory = merged;
    _offline = false;
    _lastSyncedAt = DateTime.now();
    await _articleCache.write(allCacheKey, merged);
    return merged;
  }

  Future<List<Article>> _resolve() async {
    await _hydrate();
    if (_memory.isEmpty) {
      _memory = await _seed();
      if (_memory.isEmpty) await refresh();
    }
    return _memory;
  }

  Future<void> _hydrate() async {
    if (_hydrated) return;
    _hydrated = true;

    final List<Article> cached = _articleCache.read(allCacheKey);
    if (cached.isNotEmpty) {
      _memory = cached;
      _lastSyncedAt = _articleCache.syncedAt(allCacheKey);
      return;
    }
    _memory = await _seed();
  }

  Future<List<Article>> _seed() async {
    final List<Article>? cached = _seedArticles;
    if (cached != null) return cached;
    try {
      final SeedData data = await _seeds.load();
      _seedArticles = data.articles;
    } catch (error) {
      AppLog.debug('OfflineFirstArticleRepository: seed unavailable: $error');
      _seedArticles = const <Article>[];
    }
    return _seedArticles!;
  }

  /// Fans out to [sources] concurrently, giving each one [sourceTimeout] and
  /// discarding individual failures.
  Future<List<Article>> _collect(List<FeedSource> sources) async {
    final List<Future<List<Article>>> pending = <Future<List<Article>>>[
      for (final FeedSource source in sources)
        source
            .fetch(limit: perSourceLimit)
            .timeout(sourceTimeout, onTimeout: () => const <Article>[])
            .catchError((Object error) {
              AppLog.debug(
                'OfflineFirstArticleRepository(${source.config.id}): $error',
              );
              return const <Article>[];
            }),
    ];

    final List<Article> collected = <Article>[];
    for (final List<Article> batch in await Future.wait(pending)) {
      collected.addAll(batch);
    }
    return collected;
  }

  static List<Article> _merge(List<Article> existing, List<Article> incoming) {
    final Map<String, Article> byId = <String, Article>{};
    for (final Article article in <Article>[...existing, ...incoming]) {
      final Article? current = byId[article.id];
      if (current == null || article.publishedAt.isAfter(current.publishedAt)) {
        byId[article.id] = article;
      }
    }
    return _sortDescending(byId.values.toList(growable: false));
  }

  static List<Article> _sortDescending(List<Article> articles) {
    final List<Article> sorted = List<Article>.of(articles);
    sorted.sort(
      (Article a, Article b) => b.publishedAt.compareTo(a.publishedAt),
    );
    return sorted;
  }

  static List<Article> _filter(List<Article> articles, String categoryId) {
    if (categoryId.isEmpty || categoryId == 'top') {
      return List<Article>.of(articles);
    }
    return <Article>[
      for (final Article article in articles)
        if (article.categoryId == categoryId) article,
    ];
  }

  static List<Article> _cap(List<Article> articles, int limit) =>
      articles.length > limit ? articles.sublist(0, limit) : articles;
}
