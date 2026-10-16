import '../../../../core/domain/models/article.dart';
import '../../../../core/domain/models/news_category.dart';

export '../../../../core/domain/models/article.dart';
export '../../../../core/domain/models/news_category.dart';

/// The sections one category feed is split into for the News tab.
///
/// The News screen is a fixed editorial composition — one hero, a two-column
/// sub-grid, then the rest of the stream — so the slicing rules live in a
/// pure-Dart value object instead of in `build`. That keeps the layout widgets
/// declarative and lets the boundary rules (breaking-story promotion,
/// de-duplication, grid/list split) be unit-tested without a widget tree.
class NewsCategoryFeed {
  /// An empty feed, used while loading and for categories with no stories.
  const NewsCategoryFeed.empty()
    : categoryId = '',
      label = '',
      hero = null,
      grid = const <Article>[],
      list = const <Article>[];

  const NewsCategoryFeed({
    required this.categoryId,
    required this.label,
    required this.hero,
    required this.grid,
    required this.list,
  });

  /// Slug of the category these slices were derived from.
  final String categoryId;

  /// Display label of the category, e.g. `Cars and Vehicles`.
  final String label;

  /// Newest / most prominent story, rendered by `ArticleHeroCard`.
  final Article? hero;

  /// Up to [NewsCategoryFeedViewModel.maxGridStories] stories for the
  /// two-column grid.
  final List<Article> grid;

  /// Remaining stories, rendered as `ArticleTile` rows.
  final List<Article> list;

  /// True when there is nothing to show at all.
  bool get isEmpty => hero == null;

  /// Every story in the feed, in render order, without duplicates.
  List<Article> get all => <Article>[?hero, ...grid, ...list];

  /// Total number of stories the feed renders.
  int get total => all.length;

  @override
  String toString() =>
      'NewsCategoryFeed($categoryId, hero: ${hero?.id}, grid: ${grid.length}, list: ${list.length})';
}

/// Turns a repository result into the News tab's hero / grid / list slices.
///
/// `ArticleRepository.byCategory` already returns stories newest-first, so the
/// view model never re-sorts the stream: it preserves the editorial order of the
/// data layer and only decides *where* the boundaries fall and which single
/// story earns the hero slot.
abstract final class NewsCategoryFeedViewModel {
  /// How many stories the two-column grid shows at most.
  static const int maxGridStories = 6;

  /// Builds the render model for [articles] in [categoryId].
  ///
  /// Rules, in order:
  /// 1. Duplicates are dropped by [Article.id] — a story ingested from two
  ///    sources must never appear twice in one stream.
  /// 2. The hero is the most prominent story, not blindly the first: a
  ///    breaking (or, failing that, live) story is promoted into the hero slot
  ///    even when the data layer ranked it lower. See [heroOf].
  /// 3. The next [maxGridStories] stories fill the grid; everything after that
  ///    continues in the list section. `skip`/`take` are used rather than
  ///    `sublist` so every length — including the 1- and 7-story boundaries —
  ///    is safe without extra guards.
  static NewsCategoryFeed build(List<Article> articles, String categoryId) {
    final String label = NewsCategories.byId(categoryId).label;
    if (articles.isEmpty) {
      return NewsCategoryFeed(
        categoryId: categoryId,
        label: label,
        hero: null,
        grid: const <Article>[],
        list: const <Article>[],
      );
    }

    final List<Article> ordered = _uniqueById(articles);
    final Article hero = heroOf(ordered)!;
    // The remaining stories keep their incoming order — no reshuffling beyond
    // lifting the hero out of the stream.
    final List<Article> rest = <Article>[
      for (final Article article in ordered)
        if (!identical(article, hero)) article,
    ];

    return NewsCategoryFeed(
      categoryId: categoryId,
      label: label,
      hero: hero,
      grid: rest.take(maxGridStories).toList(growable: false),
      list: rest.skip(maxGridStories).toList(growable: false),
    );
  }

  /// Convenience overload that takes the [NewsCategory] rather than its id.
  static NewsCategoryFeed buildForArticles(
    List<Article> articles,
    NewsCategory category,
  ) => build(articles, category.id);

  /// The hero a feed would render, without building the whole model.
  ///
  /// Prominence order: breaking beats live beats newest-first. The data layer's
  /// order wins every remaining tie, which keeps the choice deterministic for a
  /// feed with two equally prominent stories.
  static Article? heroOf(List<Article> articles) {
    if (articles.isEmpty) {
      return null;
    }
    final List<Article> unique = _uniqueById(articles);
    Article hero = unique.first;
    for (final Article candidate in unique.skip(1)) {
      if (_isMoreProminent(candidate, hero)) {
        hero = candidate;
      }
    }
    return hero;
  }

  /// Prominence used to pick the hero of the feed.
  static bool _isMoreProminent(Article candidate, Article current) {
    if (candidate.isBreaking != current.isBreaking) {
      return candidate.isBreaking;
    }
    if (candidate.isLive != current.isLive) {
      return candidate.isLive;
    }
    return candidate.publishedAt.isAfter(current.publishedAt);
  }

  /// Keeps the first occurrence of every id, preserving the incoming
  /// (newest-first) order. The input list is never mutated.
  static List<Article> _uniqueById(List<Article> articles) {
    final Set<String> seen = <String>{};
    final List<Article> unique = <Article>[];
    for (final Article article in articles) {
      if (seen.add(article.id)) {
        unique.add(article);
      }
    }
    return unique;
  }
}
