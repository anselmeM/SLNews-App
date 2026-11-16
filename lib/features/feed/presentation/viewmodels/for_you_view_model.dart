import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/feed_mix.dart';
import '../../../../core/domain/models/article.dart';
import '../../../../core/domain/models/follow_models.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/controllers.dart';

/// Immutable, render-ready snapshot of the For You screen.
///
/// Everything here is derived: the page never merges or de-duplicates streams
/// itself, so the non-trivial ordering rules live in one pure, testable place.
class ForYouFeed {
  const ForYouFeed({
    required this.hero,
    required this.stream,
    required this.breakingCount,
    required this.activeLocation,
    required this.isOffline,
    required this.lastSyncedAt,
  });

  /// Carousel cards: breaking stories first, then the newest remaining ones.
  final List<Article> hero;

  /// Tile stream: the location feed first, then every other story, newest first.
  final List<Article> stream;

  /// Number of breaking stories across the whole merged stream.
  final int breakingCount;

  /// Location driving the local section header and the weather chip.
  final NewsLocation activeLocation;

  final bool isOffline;
  final DateTime? lastSyncedAt;

  /// True when no story is available from any source.
  bool get isEmpty => hero.isEmpty && stream.isEmpty;

  /// True when at least one merged story is flagged breaking.
  bool get hasBreaking => breakingCount > 0;
}

/// Derives [ForYouFeed] from the four ingest-backed streams.
///
/// Pure Dart (no widgets, no I/O) so the merge/order/limit rules can be
/// unit-tested without pumping a frame.
abstract final class ForYouViewModel {
  /// How many stories the hero carousel shows (and how many the tile stream
  /// skips so a story is never rendered twice on one screen).
  static const int heroLimit = 6;

  /// Stories one followed topic may contribute per feed build.
  ///
  /// A cap keeps a handful of follows from swamping the Sierra Leone-first mix;
  /// the ranking boost then decides where those stories land.
  static const int followedFeedLimit = 6;

  /// Merges the three streams by [Article.id], newest first.
  ///
  /// Later sources win on an id collision because they are the more specific
  /// feeds (`location`, then `extra`); the duplicate is simply dropped.
  static List<Article> merge(
    List<Article> topStories, {
    List<Article> locationStories = const <Article>[],
    List<Article> extraStories = const <Article>[],
  }) {
    final Map<String, Article> byId = <String, Article>{};
    for (final List<Article> source in <List<Article>>[
      topStories,
      locationStories,
      extraStories,
    ]) {
      for (final Article article in source) {
        byId[article.id] = article;
      }
    }
    return byId.values.toList(growable: false)
      ..sort((Article a, Article b) => b.publishedAt.compareTo(a.publishedAt));
  }

  /// Number of explicit follow matches an article earns.
  ///
  /// Follow ids are prefixed (`topic:`, `publisher:`, `city:`), so a story can
  /// match through its category, one of its tags, or its publisher.
  static int personalMatch(Article article, Set<String> followingIds) {
    if (followingIds.isEmpty) return 0;
    int matches = 0;
    if (followingIds.contains('topic:${article.categoryId}')) matches += 2;
    if (followingIds.contains('publisher:${article.publisher.id}')) {
      matches += 2;
    }
    for (final String tag in article.tags) {
      if (followingIds.contains('topic:$tag')) matches += 1;
      if (followingIds.contains('city:$tag')) matches += 1;
    }
    return matches;
  }

  static DateTime _effectiveTime(Article article, Set<String> followingIds) {
    if (personalMatch(article, followingIds) == 0) return article.publishedAt;
    return article.publishedAt.add(const Duration(hours: 36));
  }

  /// Audience-first ordering; the optional [within] comparator keeps the
  /// existing personalisation and breaking rules inside each bucket.
  static void _sortForAudience(
    List<Article> articles,
    Set<String> ids, {
    bool boundedFollowWindow = false,
  }) {
    articles.sort((Article a, Article b) {
      return FeedMix.compare(
        a,
        b,
        within: (Article left, Article right) {
          if (left.isBreaking != right.isBreaking) {
            return left.isBreaking ? -1 : 1;
          }
          if (boundedFollowWindow) {
            return _effectiveTime(
              right,
              ids,
            ).compareTo(_effectiveTime(left, ids));
          }
          return personalMatch(right, ids).compareTo(personalMatch(left, ids));
        },
      );
    });
  }

  /// Builds the render-ready feed exactly as the screen renders it.
  ///
  /// The carousel is filled from [topStories] only (breaking first), so the
  /// local and latest sections keep every story the hero did not take.
  static ForYouFeed build({
    required List<Article> topStories,
    required List<Article> locationStories,
    required List<Article> extraStories,
    required NewsLocation activeLocation,
    required bool isOffline,
    DateTime? lastSyncedAt,
    int heroLimit = ForYouViewModel.heroLimit,
    int sportsOutsideLimit = 2,
    Set<String> followingIds = const <String>{},
  }) {
    final List<Article> merged = merge(
      topStories,
      locationStories: locationStories,
      extraStories: extraStories,
    );

    // The home surfaces are Sierra Leone-first, then international, then a
    // small sports tail. Sports-only feeds are numerous and would otherwise
    // crowd out local reporting.
    final List<Article> heroCandidates = topStories
        .where((Article article) => !FeedMix.isSports(article))
        .toList(growable: false);
    _sortForAudience(heroCandidates, followingIds);
    final List<Article> heroPool = heroCandidates.isNotEmpty
        ? heroCandidates
        : topStories;
    final List<Article> hero = heroPool.take(heroLimit).toList(growable: false);

    final Set<String> heroIds = <String>{
      for (final Article article in hero) article.id,
    };

    // Local stream: the location feed, minus whatever the carousel consumed.
    final List<Article> localStream = locationStories
        .where(
          (Article article) =>
              !heroIds.contains(article.id) && !FeedMix.isSports(article),
        )
        .toList(growable: false);
    _sortForAudience(localStream, followingIds, boundedFollowWindow: true);
    final Set<String> shown = <String>{
      for (final Article article in localStream) article.id,
      ...heroIds,
    };

    // Latest stream: every non-sports merged story the reader cannot already
    // see above, then the capped sports tail.
    final List<Article> latestStream = merged
        .where(
          (Article article) =>
              !shown.contains(article.id) && !FeedMix.isSports(article),
        )
        .toList(growable: false);
    _sortForAudience(latestStream, followingIds, boundedFollowWindow: true);
    final List<Article> sportsStream = FeedMix.limitedSports(
      merged.where((Article article) => !heroIds.contains(article.id)),
      limit: sportsOutsideLimit,
    );

    return ForYouFeed(
      hero: hero,
      stream: <Article>[...localStream, ...latestStream, ...sportsStream],
      breakingCount: merged
          .where((Article article) => article.isBreaking)
          .length,
      activeLocation: activeLocation,
      isOffline: isOffline,
      lastSyncedAt: lastSyncedAt,
    );
  }
}

/// The resolved For You feed, or `null` while a stream that feeds it has not
/// produced a value yet.
///
/// `null` is deliberately distinct from an empty [ForYouFeed] so the page can
/// tell "still loading" from "genuinely nothing to show".
final Provider<ForYouFeed?> forYouFeedProvider = Provider<ForYouFeed?>((
  Ref ref,
) {
  final String locationId = ref
      .watch(settingsControllerProvider)
      .activeLocationId;
  final AsyncValue<List<Article>> top = ref.watch(topStoriesProvider);
  final AsyncValue<List<Article>> extra = ref.watch(
    categoryFeedProvider('top'),
  );

  // An error has its own full-screen state on the page; `null` here means the
  // feed is simply not renderable yet.
  if (top.hasError || extra.hasError) return null;
  if (top.isLoading || extra.isLoading) return null;

  final NewsLocation location = SlLocations.all.firstWhere(
    (NewsLocation candidate) => candidate.id == locationId,
    orElse: () => SlLocations.fallback,
  );

  // A bare ProviderScope (widget test) leaves the repository un-overridden and
  // it throws `UnimplementedError`; treat that as "no offline signal yet".
  bool isOffline = false;
  DateTime? lastSyncedAt;
  try {
    isOffline = ref.watch(articleRepositoryProvider).isOffline;
    lastSyncedAt = ref.read(articleRepositoryProvider).lastSyncedAt;
  } on UnimplementedError {
    isOffline = false;
  }

  // Personalisation is a boost, never a gate: an un-overridden test scope must
  // still render the feed. Followed topics also contribute their own category
  // feed, so following Politics brings politics stories in even when the home
  // pool has none — before this, a follow could only reorder what was already
  // there.
  Set<String> followingIds = const <String>{};
  List<Article> followedStories = const <Article>[];
  try {
    final FollowingSnapshot snapshot = ref.watch(followingControllerProvider);
    followingIds = snapshot.followedIds.toSet();
    final Set<String> followedTopics = <String>{
      for (final String id in followingIds)
        if (id.startsWith('topic:')) id.substring('topic:'.length),
    }..remove('top');
    final List<Article> stories = <Article>[];
    for (final String categoryId in followedTopics) {
      final List<Article>? feed = ref
          .watch(categoryFeedProvider(categoryId))
          .value;
      if (feed == null) continue;
      stories.addAll(feed.take(ForYouViewModel.followedFeedLimit));
    }
    followedStories = stories;
  } on Object {
    followingIds = const <String>{};
    followedStories = const <Article>[];
  }

  return ForYouViewModel.build(
    followingIds: followingIds,
    topStories: top.value ?? const <Article>[],
    // The feed covers Sierra Leone as a whole: there is no city-scoped rail
    // until the reader asks for one, so the "From <city>" section stays absent.
    locationStories: const <Article>[],
    extraStories: <Article>[
      ...(extra.value ?? const <Article>[]),
      ...followedStories,
    ],
    activeLocation: location,
    isOffline: isOffline,
    lastSyncedAt: lastSyncedAt,
  );
}, name: 'forYouFeed');
