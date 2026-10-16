import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Orders [articles] newest first without mutating the input.
  static List<Article> _newestFirst(Iterable<Article> articles) {
    return articles.toList(growable: false)
      ..sort((Article a, Article b) => b.publishedAt.compareTo(a.publishedAt));
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
  }) {
    final List<Article> merged = merge(
      topStories,
      locationStories: locationStories,
      extraStories: extraStories,
    );

    // Breaking stories are promoted ahead of newer non-breaking ones so the
    // "Top stories" carousel opens on what the reader must not miss. Each group
    // is ordered newest first, so the carousel never depends on the order the
    // repository happened to return.
    final List<Article> heroPool = <Article>[
      ..._newestFirst(topStories.where((Article article) => article.isBreaking)),
      ..._newestFirst(topStories.where((Article article) => !article.isBreaking)),
    ];
    final List<Article> hero = heroPool.take(heroLimit).toList(growable: false);

    final Set<String> heroIds = <String>{
      for (final Article article in hero) article.id,
    };

    // Local stream: the location feed, minus whatever the carousel consumed.
    final List<Article> localStream = locationStories
        .where((Article article) => !heroIds.contains(article.id))
        .toList(growable: false);
    final Set<String> shown = <String>{
      for (final Article article in localStream) article.id,
    };

    // Latest stream: every merged story the reader cannot already see above,
    // still newest first (the merged order is preserved).
    final List<Article> latestStream = merged
        .where(
          (Article article) => !heroIds.contains(article.id) && !shown.contains(article.id),
        )
        .toList(growable: false);

    return ForYouFeed(
      hero: hero,
      stream: <Article>[...localStream, ...latestStream],
      breakingCount: merged.where((Article article) => article.isBreaking).length,
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
final Provider<ForYouFeed?> forYouFeedProvider = Provider<ForYouFeed?>((Ref ref) {
  final String locationId = ref.watch(settingsControllerProvider).activeLocationId;
  final AsyncValue<List<Article>> top = ref.watch(topStoriesProvider);
  final AsyncValue<List<Article>> local = ref.watch(locationFeedProvider(locationId));
  final AsyncValue<List<Article>> extra = ref.watch(categoryFeedProvider('top'));

  // An error has its own full-screen state on the page; `null` here means the
  // feed is simply not renderable yet.
  if (top.hasError || local.hasError || extra.hasError) return null;
  if (top.isLoading || local.isLoading || extra.isLoading) return null;

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

  return ForYouViewModel.build(
    topStories: top.value ?? const <Article>[],
    locationStories: local.value ?? const <Article>[],
    extraStories: extra.value ?? const <Article>[],
    activeLocation: location,
    isOffline: isOffline,
    lastSyncedAt: lastSyncedAt,
  );
}, name: 'forYouFeed');
