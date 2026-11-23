import 'package:flutter/material.dart';

import '../../../core/widgets/header_actions.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ads/sponsorship_launcher.dart';
import '../../../core/domain/models/ad_placement.dart';
import '../../../core/domain/models/ad_unit.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tracked_ad_card.dart';
import '../../../core/widgets/article_hero_card.dart';
import '../../../core/widgets/article_tile.dart';
import '../../../core/widgets/overflow_menu_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/sl_page_scaffold.dart';
import '../../feed/presentation/widgets/article_actions.dart';
import '../../../core/widgets/state_views.dart';
import 'viewmodels/category_feed_view_model.dart';
import 'widgets/category_pill_header.dart';
import 'widgets/category_story_grid.dart';

/// Index of the `Latest` list row the in-stream ad is inserted after.
const int kNewsAdAfterRow = 3;

/// Tab 2 — the category browser (`/news`).
///
/// Reproduces the reference "Cars and Vehicles" screen: a pinned, horizontally
/// scrollable pill strip, a large category title, a 420pt hero, a two-column
/// grid of the next stories, and the rest of the stream as list rows with one
/// native ad inserted after the third row.
///
/// The selected pill is app-level state (`selectedCategoryProvider`) so it
/// survives tab switches. Scroll position is deliberately *not* app-level: it is
/// local widget state owned by [_NewsViewHost], which keeps one offset per
/// category so switching pills restores the previous reading position.
class NewsPage extends ConsumerWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _NewsViewHost();
  }
}

/// Owns the per-category scroll offsets for the lifetime of the News tab.
class _NewsViewHost extends ConsumerStatefulWidget {
  const _NewsViewHost();

  @override
  ConsumerState<_NewsViewHost> createState() => _NewsViewHostState();
}

class _NewsViewHostState extends ConsumerState<_NewsViewHost> {
  /// `SlPageScaffold` owns its scroll view, so the page cannot hand it one
  /// controller per category. It uses a single controller for the visible list
  /// and remembers where each category was left instead.
  final ScrollController _scrollController = ScrollController();

  /// Last known offset per category id. Missing means "never scrolled", i.e. 0.
  final Map<String, double> _offsets = <String, double>{};

  String _categoryId = '';

  /// Set while the selected category is changing: the next frame restores the
  /// new category's saved offset (or 0 for a first visit).
  bool _pendingRestore = false;

  @override
  void initState() {
    super.initState();
    _categoryId = ref.read(selectedCategoryProvider);
    // The pill tap also handles this, but the category can change from outside
    // this widget (deep link, "See all" elsewhere), so the provider stays the
    // single source of truth.
    ref.listenManual<String>(selectedCategoryProvider, (
      String? previous,
      String next,
    ) {
      if (previous == next) {
        return;
      }
      _rememberOffset();
      _categoryId = next;
      _pendingRestore = true;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Stores the visible offset so it can be restored on the next visit.
  void _rememberOffset() {
    if (_scrollController.hasClients) {
      _offsets[_categoryId] = _scrollController.offset;
    }
  }

  void _selectCategory(NewsCategory category) {
    if (category.id == _categoryId) {
      return;
    }
    // Reset as part of selecting, so a category always opens at its top even
    // when the reader had scrolled far down the previous one. `.jumpTo` on a
    // fresh category is always 0, so this is a no-op there.
    _offsets[category.id] = 0;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _categoryId = category.id;
    _pendingRestore = true;
    ref.read(selectedCategoryProvider.notifier).select(category.id);
  }

  @override
  Widget build(BuildContext context) {
    final String selectedCategoryId = ref.watch(selectedCategoryProvider);
    if (selectedCategoryId != _categoryId) {
      // A change that arrived through the provider listener before this frame.
      _categoryId = selectedCategoryId;
    }

    if (_pendingRestore) {
      _pendingRestore = false;
      // The new category's slivers only exist after this frame, so the offset
      // has to be applied once they are attached.
      WidgetsBinding.instance.addPostFrameCallback(
        (Duration _) => _restoreOffset(),
      );
    }

    return SlPageScaffold(
      title: 'News',
      brandMark: 'SLNews',
      actions: const <Widget>[HeaderActions()],
      bottom: CategoryPillHeader(
        categories: NewsCategories.all,
        selectedId: selectedCategoryId,
        onSelected: _selectCategory,
        showIcons: false,
      ),
      onRefresh: ref.read(refreshFeedsProvider),
      slivers: <Widget>[
        _NewsFeed(
          // Keying the stream by category gives the scroll view a clean
          // lifecycle per category and keeps the async loading state honest.
          key: ValueKey<String>('news-feed-$selectedCategoryId'),
          categoryId: selectedCategoryId,
        ),
      ],
    );
  }

  void _restoreOffset() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    final double target = _offsets[_categoryId] ?? 0;
    if ((_scrollController.offset - target).abs() < 0.5) {
      return;
    }
    _scrollController.jumpTo(
      target.clamp(0, _scrollController.position.maxScrollExtent),
    );
  }
}

/// The scrollable body for one category.
///
/// Rendered as slivers rather than a nested scroll view so the pill strip stays
/// pinned while everything below it scrolls as one surface.
class _NewsFeed extends ConsumerWidget {
  const _NewsFeed({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Article>> feed = ref.watch(
      categoryFeedProvider(categoryId),
    );
    final String label = NewsCategories.byId(categoryId).label;

    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverToBoxAdapter(child: SlPageTitle(title: label, onTap: null)),
        feed.when(
          loading: () => const _NewsLoadingSlivers(),
          error: (Object error, StackTrace stackTrace) => SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorStateView(
              message: "We couldn't load this category.",
              onRetry: () => ref.invalidate(categoryFeedProvider),
            ),
          ),
          data: (List<Article> articles) {
            final NewsCategoryFeed model = NewsCategoryFeedViewModel.build(
              articles,
              categoryId,
            );
            if (model.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyStateView(
                  title: 'Nothing here yet',
                  message:
                      'No ${label.toLowerCase()} stories right now — check back soon.',
                  icon: Icons.newspaper_outlined,
                ),
              );
            }
            final bool usingFallback =
                categoryId != 'top' &&
                !articles.any(
                  (Article article) => article.categoryId == categoryId,
                );
            return SliverMainAxisGroup(
              slivers: <Widget>[
                if (usingFallback)
                  SliverToBoxAdapter(
                    child: _CategoryFallbackNotice(label: label),
                  ),
                _NewsContentSlivers(feed: model),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Shown when the selected category has no current stories and the provider
/// deliberately falls back to the latest general news.
class _CategoryFallbackNotice extends StatelessWidget {
  const _CategoryFallbackNotice({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surfaceMuted,
          borderRadius: AppRadius.cardRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            'No ${label.toLowerCase()} stories right now — showing the latest news.',
            style: context.typography.caption.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The loaded state: hero, grid section, list section and the inline ad.
class _NewsContentSlivers extends ConsumerWidget {
  const _NewsContentSlivers({required this.feed});

  final NewsCategoryFeed feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Article hero = feed.hero!;
    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          sliver: SliverToBoxAdapter(
            // The hero's own metadata row (wordmark + age + actions) has the
            // same non-flexible layout as the grid tile's, so it gets the same
            // text-scale clamp; the page title, pills and list rows keep the
            // reader's full scale.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: kCategoryGridMaxTextScale,
              child: ArticleHeroCard(
                article: hero,
                height: 420,
                onTap: () => _openArticle(context, hero),
                onLike: () => _toggleLike(ref, hero.id),
                onMore: (ArticleAction action) =>
                    _handleAction(context, ref, hero, action),
              ),
            ),
          ),
        ),
        if (feed.grid.isNotEmpty) ...<Widget>[
          SliverToBoxAdapter(
            child: SectionHeader(title: 'More in ${feed.label}'),
          ),
          CategoryStoryGrid(
            articles: feed.grid,
            onArticleTap: (Article article) => _openArticle(context, article),
            onArticleMore: (Article article, ArticleAction action) =>
                _handleAction(context, ref, article, action),
          ),
        ],
        SliverList(
          delegate: SliverChildListDelegate(<Widget>[
            // First row, so the section header keeps its own 20pt top padding
            // and the card gap stays at the standard 12pt.
            const SectionHeader(title: 'Latest'),
            for (int index = 0; index < feed.list.length; index++) ...<Widget>[
              if (index == kNewsAdAfterRow) const _InStreamAd(),
              _ArticleRow(
                article: feed.list[index],
                onTap: () => _openArticle(context, feed.list[index]),
                onLike: () => _toggleLike(ref, feed.list[index].id),
                onMore: (ArticleAction action) =>
                    _handleAction(context, ref, feed.list[index], action),
              ),
            ],
          ]),
        ),
      ],
    );
  }
}

/// The loading state: a hero block plus four list-row skeletons.
class _NewsLoadingSlivers extends StatelessWidget {
  const _NewsLoadingSlivers();

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate(<Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: HeroCardSkeleton(),
        ),
        for (int index = 0; index < 4; index++)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: NewsRowInset(child: ArticleTileSkeleton()),
          ),
      ]),
    );
  }
}

/// One list-row card, with the standard 12pt gap below it.
class _ArticleRow extends StatelessWidget {
  const _ArticleRow({
    required this.article,
    required this.onTap,
    required this.onLike,
    required this.onMore,
  });

  final Article article;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final ValueChanged<ArticleAction> onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: NewsRowInset(
        child: ArticleTile(
          article: article,
          onTap: onTap,
          onLike: onLike,
          onMore: onMore,
        ),
      ),
    );
  }
}

/// Applies the 16pt page gutter to a full-bleed child.
class NewsRowInset extends StatelessWidget {
  const NewsRowInset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: child,
    );
  }
}

/// One native-style ad unit drawn from the `feed` placement.
///
/// Placement is intentionally best-effort: while the rotation loads, if it is
/// empty, or if it fails, this renders nothing at all, so an ad can never
/// interrupt the stream with a blank card or an error.
class _InStreamAd extends ConsumerWidget {
  const _InStreamAd();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AdUnit> units =
        ref.watch(adUnitsProvider(AdPlacement.feed.wire)).asData?.value ??
        const <AdUnit>[];
    if (units.isEmpty) {
      return const SizedBox.shrink();
    }
    final AdUnit unit = units.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: NewsRowInset(
        child: TrackedAdCard(
          unit: unit,
          onCtaPressed: () => openSponsorship(context, ref, unit),
          onOpened: (AdUnit opened) => openSponsorship(context, ref, opened),
        ),
      ),
    );
  }
}

/// Opens the reader for [article].
void _openArticle(BuildContext context, Article article) {
  context.push(AppRoutes.articleFor(article.id));
}

/// Toggles the like state through the shared controller.
void _toggleLike(WidgetRef ref, String articleId) {
  ref.read(likesControllerProvider.notifier).toggle(articleId);
}

/// Routes the per-article kebab actions through the shared handler, so the
/// News tab saves, shares, opens and follows exactly like the feed does.
Future<void> _handleAction(
  BuildContext context,
  WidgetRef ref,
  Article article,
  ArticleAction action,
) => handleArticleAction(context, ref, article, action);
