import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/sources/espn_source.dart';
import '../../../../core/domain/feed_mix.dart';
import '../../../../core/domain/models/article.dart';
import '../../../../core/domain/models/app_settings.dart';
import '../../../../core/domain/models/follow_models.dart';
import '../../../../core/domain/models/personalization_profile.dart';
import '../../../../core/domain/personalization.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/controllers.dart';
import '../../../../core/providers/personalization_profile.dart';
import '../../../../core/providers/reading_history_provider.dart';
import '../../../../core/utils/app_log.dart';
import '../../../../core/utils/time_ago.dart';

/// Immutable, render-ready snapshot of the For You screen.
///
/// Everything here is derived: the page never merges or de-duplicates streams
/// itself, so the non-trivial ordering rules live in one pure, testable place.
class ForYouFeed {
  const ForYouFeed({
    required this.hero,
    required this.stream,
    this.briefing = const <Article>[],
    this.followingStories = const <Article>[],
    required this.breakingCount,
    this.breakingAlert,
    required this.activeLocation,
    required this.isOffline,
    required this.lastSyncedAt,
  });

  /// Carousel cards: breaking stories first, then the newest remaining ones.
  final List<Article> hero;

  /// Tile stream: the location feed first, then every other story, newest first.
  final List<Article> stream;

  /// Up to three stories promoted into the merged weather/briefing card.
  ///
  /// They are taken from [stream], so the carousel is never duplicated. The
  /// breaking alert story is excluded because it already has its own row.
  final List<Article> briefing;

  /// Explicitly followed stories promoted to the "From your follows" rail.
  /// Kept out of [stream] so the same story never appears twice on the page.
  final List<Article> followingStories;

  /// The one fresh breaking story that may be promoted to the alert row.
  ///
  /// This is deliberately a single story, not a feed-wide boolean: a stale
  /// breaking flag must not keep a permanent tag on screen.
  final Article? breakingAlert;

  /// Number of fresh breaking stories in the merged stream.
  final int breakingCount;

  /// Location driving the weather module in the briefing card.
  final NewsLocation activeLocation;

  final bool isOffline;
  final DateTime? lastSyncedAt;

  /// True when no story is available from any source.
  bool get isEmpty =>
      hero.isEmpty && stream.isEmpty && followingStories.isEmpty;

  /// True when a fresh breaking story should show the alert row.
  bool get hasBreaking => breakingAlert != null;
}

/// Derives [ForYouFeed] from the four ingest-backed streams.
///
/// Pure Dart (no widgets, no I/O) so the merge/order/limit rules can be
/// unit-tested without pumping a frame.
abstract final class ForYouViewModel {
  /// How many stories the hero carousel shows (and how many the tile stream
  /// skips so a story is never rendered twice on one screen).
  static const int heroLimit = 6;

  /// A breaking story is only an *alert* while it is fresh. This also prevents
  /// an old cached row (or a stale feed flag) from keeping the header tag on
  /// screen indefinitely.
  static const Duration breakingWindow = Duration(hours: 6);

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
      final String lower = tag.toLowerCase();
      if (followingIds.contains(lower) &&
          (lower.startsWith('team:') || lower.startsWith('league:'))) {
        matches += 2;
        continue;
      }
      if (followingIds.contains('topic:$lower')) matches += 1;
      if (followingIds.contains('city:$lower')) matches += 1;
    }
    return matches;
  }

  /// Normalizes city-scoped search candidates before follow matching.
  ///
  /// A tagged story passes directly. A title match is treated as a city match
  /// and receives the normalized city tag; a mere body/summary mention does not
  /// qualify, so unrelated search hits cannot enter For You this way.
  static List<Article> cityCandidates(
    Iterable<Article> articles,
    FollowTarget target, {
    int limit = followedFeedLimit,
  }) {
    final String cityId = target.id.toLowerCase();
    final String label = target.label.trim().toLowerCase();
    if (label.isEmpty) return const <Article>[];
    final List<Article> matches = <Article>[];
    for (final Article article in articles) {
      final bool tagged = article.tags.any((String tag) {
        final String lower = tag.trim().toLowerCase();
        return lower == cityId || 'city:$lower' == cityId;
      });
      final bool titleMatch = article.title.toLowerCase().contains(label);
      if (!tagged && !titleMatch) continue;
      matches.add(
        tagged
            ? article
            : article.copyWith(
                tags: List<String>.unmodifiable(<String>[
                  ...article.tags,
                  cityId,
                ]),
              ),
      );
      if (matches.length >= limit) break;
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
    ReaderSignals? signals,
    DateTime? now,
    bool personalize = false,
  }) {
    // The opt-out must suppress follow ranking inside the build path; callers
    // should not be able to re-enable it accidentally by passing ids.
    final Set<String> effectiveIds = personalize ? ids : const <String>{};
    articles.sort((Article a, Article b) {
      return FeedMix.compare(
        a,
        b,
        within: (Article left, Article right) {
          if (left.isBreaking != right.isBreaking) {
            return left.isBreaking ? -1 : 1;
          }
          if (personalize && signals != null && !signals.isEmpty) {
            return PersonalizationEngine.compare(
              left,
              right,
              signals,
              now: now,
            );
          }
          if (boundedFollowWindow) {
            return _effectiveTime(
              right,
              effectiveIds,
            ).compareTo(_effectiveTime(left, effectiveIds));
          }
          return personalMatch(
            right,
            effectiveIds,
          ).compareTo(personalMatch(left, effectiveIds));
        },
      );
    });
    if (personalize && signals != null && !signals.isEmpty) {
      final List<Article> explored = PersonalizationEngine.reserveExploration(
        articles,
        signals,
      );
      // Pools are often fixed-length; replace elements rather than resize.
      articles.setAll(0, explored);
    }
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
    DateTime? now,
    int heroLimit = ForYouViewModel.heroLimit,
    int sportsOutsideLimit = 2,
    Set<String> followingIds = const <String>{},
    ReaderSignals signals = const ReaderSignals(),
    bool personalizeFeed = false,
    Set<String> dismissedIds = const <String>{},
  }) {
    List<Article> visible(List<Article> stories) => stories
        .where((Article article) => !dismissedIds.contains(article.id))
        .toList(growable: false);

    final List<Article> visibleTop = visible(topStories);
    final List<Article> visibleLocation = visible(locationStories);
    final List<Article> visibleExtra = visible(extraStories);
    final List<Article> merged = merge(
      visibleTop,
      locationStories: visibleLocation,
      extraStories: visibleExtra,
    );
    final DateTime reference = now ?? appNow();
    final DateTime breakingCutoff = reference.subtract(breakingWindow);

    // The home surfaces are Sierra Leone-first, then international, then a
    // small sports tail. Sports-only feeds are numerous and would otherwise
    // crowd out local reporting.
    final List<Article> heroCandidates = visibleTop
        .where((Article article) => !FeedMix.isSports(article))
        .toList(growable: false);
    _sortForAudience(
      heroCandidates,
      followingIds,
      signals: signals,
      now: reference,
      personalize: personalizeFeed,
    );
    final List<Article> heroPool = heroCandidates.isNotEmpty
        ? heroCandidates
        : topStories;
    final List<Article> hero = personalizeFeed
        ? PersonalizationEngine.diversify(heroPool, limit: heroLimit)
        : heroPool.take(heroLimit).toList(growable: false);

    final Set<String> heroIds = <String>{
      for (final Article article in hero) article.id,
    };

    // Explicit follows get their own, explainable rail. Keep these stories out
    // of the stream so they cannot appear twice in one scroll.
    final List<Article> followingStories = personalizeFeed
        ? PersonalizationEngine.followedStories(
            merged,
            signals,
            excludeIds: heroIds,
          )
        : const <Article>[];
    final Set<String> followingIdsInRail = <String>{
      for (final Article article in followingStories) article.id,
    };

    // Local stream: the location feed, minus whatever the carousel or followed
    // rail consumed.
    final List<Article> localStream = visibleLocation
        .where(
          (Article article) =>
              !heroIds.contains(article.id) &&
              !followingIdsInRail.contains(article.id) &&
              !FeedMix.isSports(article),
        )
        .toList(growable: false);
    _sortForAudience(
      localStream,
      followingIds,
      boundedFollowWindow: true,
      signals: signals,
      now: reference,
      personalize: personalizeFeed,
    );
    final Set<String> shown = <String>{
      for (final Article article in localStream) article.id,
      ...heroIds,
      ...followingIdsInRail,
    };

    // Latest stream: every non-sports merged story the reader cannot already
    // see above, then the capped sports tail.
    final List<Article> latestStream = merged
        .where(
          (Article article) =>
              !shown.contains(article.id) &&
              !followingIdsInRail.contains(article.id) &&
              !FeedMix.isSports(article),
        )
        .toList(growable: false);
    _sortForAudience(
      latestStream,
      followingIds,
      boundedFollowWindow: true,
      signals: signals,
      now: reference,
      personalize: personalizeFeed,
    );
    final List<Article> sportsPool = merged
        .where(
          (Article article) =>
              !heroIds.contains(article.id) && FeedMix.isSports(article),
        )
        .toList(growable: false);
    if (personalizeFeed) {
      _sortForAudience(
        sportsPool,
        followingIds,
        signals: signals,
        now: reference,
        personalize: true,
      );
    } else {
      sportsPool.sort(
        (Article a, Article b) => b.publishedAt.compareTo(a.publishedAt),
      );
    }
    final List<Article> sportsStream = sportsPool
        .take(sportsOutsideLimit)
        .toList(growable: false);

    final List<Article> activeBreaking =
        merged
            .where(
              (Article article) =>
                  article.isBreaking &&
                  article.publishedAt.isAfter(breakingCutoff),
            )
            .toList(growable: false)
          ..sort(
            (Article a, Article b) => b.publishedAt.compareTo(a.publishedAt),
          );

    final List<Article> stream = <Article>[
      ...localStream,
      ...latestStream,
      ...sportsStream,
    ];
    final Article? breakingAlert = activeBreaking.isEmpty
        ? null
        : activeBreaking.first;
    final List<Article> briefing = <Article>[];
    for (final Article article in stream) {
      if (article.id == breakingAlert?.id) continue;
      briefing.add(article);
      if (briefing.length == 3) break;
    }

    return ForYouFeed(
      hero: hero,
      stream: stream,
      briefing: List<Article>.unmodifiable(briefing),
      followingStories: List<Article>.unmodifiable(followingStories),
      breakingCount: activeBreaking.length,
      breakingAlert: breakingAlert,
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
  final AsyncValue<List<Article>> top = ref.watch(topStoriesProvider);
  final AsyncValue<List<Article>> extra = ref.watch(
    categoryFeedProvider('top'),
  );

  // An error has its own full-screen state on the page; `null` here means the
  // feed is simply not renderable yet.
  if (top.hasError || extra.hasError) return null;
  if (top.isLoading || extra.isLoading) return null;

  // Weather only: the reader-facing feed covers Sierra Leone as a whole, and
  // there is no city picker. Keeping the location out of [AppSettings] stops a
  // second, inert copy of it drifting back in.
  final NewsLocation location = ref.watch(activeLocationProvider);

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
  // pool has none.
  AppSettings settings = const AppSettings(personalizeFeed: false);
  try {
    settings = ref.watch(settingsControllerProvider);
  } on Object catch (error) {
    // If the saved preference cannot be read, fail closed rather than silently
    // personalizing an opted-out reader.
    AppLog.debug(
      'ForYou: settings unavailable, personalization disabled: $error',
    );
    settings = const AppSettings(personalizeFeed: false);
  }

  Set<String> followingIds = const <String>{};
  List<Article> followedStories = const <Article>[];
  try {
    final FollowingSnapshot snapshot = ref.watch(followingControllerProvider);
    followingIds = snapshot.followedIds.toSet();
    final List<Article> stories = <Article>[];
    for (final FollowTarget target in snapshot.followed) {
      switch (target.kind) {
        case FollowKind.topic:
          final String categoryId = target.id.startsWith('topic:')
              ? target.id.substring('topic:'.length)
              : target.id;
          if (categoryId == 'top' || categoryId == 'sports') continue;
          final AsyncValue<List<Article>> feed = ref.watch(
            categoryFeedProvider(categoryId),
          );
          if (feed.hasError) {
            AppLog.debug(
              'ForYou: followed topic ${target.id} unavailable: ${feed.error}',
            );
            continue;
          }
          final List<Article>? articles = feed.value;
          if (articles != null) {
            stories.addAll(articles.take(ForYouViewModel.followedFeedLimit));
          }
        case FollowKind.publisher:
          final String publisherId = target.id.startsWith('publisher:')
              ? target.id.substring('publisher:'.length)
              : target.id;
          final AsyncValue<List<Article>> feed = ref.watch(
            publisherArticlesProvider(publisherId),
          );
          if (feed.hasError) {
            AppLog.debug(
              'ForYou: followed publisher ${target.id} unavailable: '
              '${feed.error}',
            );
            continue;
          }
          final List<Article>? articles = feed.value;
          if (articles != null) {
            stories.addAll(articles.take(ForYouViewModel.followedFeedLimit));
          }
        case FollowKind.location:
          // There is no city feed in the repository API. Search candidates are
          // normalized by title/tag before they can affect ranking.
          final AsyncValue<List<Article>> feed = ref.watch(
            searchResultsProvider(target.label),
          );
          if (feed.hasError) {
            AppLog.debug(
              'ForYou: followed city ${target.id} unavailable: ${feed.error}',
            );
            continue;
          }
          final List<Article>? articles = feed.value;
          if (articles != null) {
            stories.addAll(ForYouViewModel.cityCandidates(articles, target));
          }
        case FollowKind.team:
          if (!EspnSource.supportsTeamId(target.id)) {
            // Unsupported clubs still get a general sports fallback rather
            // than silently producing no candidate stories.
            final AsyncValue<List<Article>> fallback = ref.watch(
              categoryFeedProvider('sports'),
            );
            if (fallback.hasError) {
              AppLog.debug(
                'ForYou: team fallback for ${target.id} unavailable: '
                '${fallback.error}',
              );
              continue;
            }
            final List<Article>? articles = fallback.value;
            if (articles != null) {
              stories.addAll(articles.take(ForYouViewModel.followedFeedLimit));
            }
            continue;
          }
          final AsyncValue<List<Article>> feed = ref.watch(
            teamNewsProvider(target.id),
          );
          if (feed.hasError) {
            AppLog.debug(
              'ForYou: followed team ${target.id} unavailable: ${feed.error}',
            );
            continue;
          }
          final List<Article>? articles = feed.value;
          if (articles != null) {
            stories.addAll(articles.take(ForYouViewModel.followedFeedLimit));
          }
        case FollowKind.league:
          final AsyncValue<List<Article>> feed = ref.watch(
            leagueNewsProvider(target.id),
          );
          if (feed.hasError) {
            AppLog.debug(
              'ForYou: followed league ${target.id} unavailable: ${feed.error}',
            );
            continue;
          }
          final List<Article>? articles = feed.value;
          if (articles != null) {
            stories.addAll(articles.take(ForYouViewModel.followedFeedLimit));
          }
      }
    }
    followedStories = stories;
  } on Object catch (error) {
    AppLog.debug('ForYou: follow candidates unavailable: $error');
    followingIds = const <String>{};
    followedStories = const <Article>[];
  }

  final PersonalizationProfile profile = ref.watch(
    personalizationProfileProvider,
  );
  ReaderSignals signals = const ReaderSignals();
  if (settings.personalizeFeed) {
    try {
      final List<Article> known = <Article>[
        ...(top.value ?? const <Article>[]),
        ...(extra.value ?? const <Article>[]),
        ...followedStories,
      ];
      final ReaderSignals currentSignals = buildReaderSignals(
        knownArticles: known,
        followedIds: followingIds,
        readIds: ref.watch(readingHistoryProvider).toSet(),
        savedIds: ref.watch(bookmarksControllerProvider),
        likedIds: ref.watch(likesControllerProvider),
      );
      signals = currentSignals.copyWith(
        topicAffinity: mergeAffinityMaps(
          currentSignals.topicAffinity,
          profile.topicAffinity(),
        ),
        publisherAffinity: mergeAffinityMaps(
          currentSignals.publisherAffinity,
          profile.publisherAffinity(),
        ),
      );
    } on Object catch (error) {
      AppLog.debug(
        'ForYou: signal construction failed, using follows only: $error',
      );
      signals = ReaderSignals(followedIds: followingIds);
    }
  }

  return ForYouViewModel.build(
    // The toggle is about ranking: followed category feeds may still contribute
    // stories, but a disabled personalisation must not boost their order.
    followingIds: settings.personalizeFeed ? followingIds : const <String>{},
    signals: signals,
    personalizeFeed: settings.personalizeFeed,
    dismissedIds: profile.dismissedArticleIds(),
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
