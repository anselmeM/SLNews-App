import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/article.dart';
import '../../../core/domain/repositories/article_repository.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/article_tile.dart';
import '../../../core/widgets/overflow_menu_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/sl_page_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import 'widgets/article_actions.dart';
import 'widgets/top_stories_carousel.dart';
import 'widgets/weather_alert_header.dart';
import 'viewmodels/for_you_view_model.dart';

/// Tab 1 — the personalised "Top stories" feed.
///
/// Reconstructs the reference screen top to bottom: offline banner, weather and
/// breaking strip on the title row, the paged hero carousel, the local stream
/// and finally the latest/other stream. All ordering, merging and de-duplication
/// lives in [ForYouViewModel] so this file only maps data to slivers.
class ForYouPage extends ConsumerWidget {
  const ForYouPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ForYouFeed? feed = ref.watch(forYouFeedProvider);
    final AsyncValue<List<Article>> topStories = ref.watch(topStoriesProvider);
    final String locationId = ref
        .watch(settingsControllerProvider)
        .activeLocationId;
    final AsyncValue<List<Article>> localStories = ref.watch(
      locationFeedProvider(locationId),
    );
    final _OfflineStatus offline = _readOffline(ref);

    final Widget content;
    if (feed == null) {
      content = topStories.hasError
          ? SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorStateView(
                onRetry: () => ref.invalidate(topStoriesProvider),
              ),
            )
          : const _FeedSkeletonSliver();
    } else if (feed.isEmpty) {
      content = const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyStateView(
          title: 'No stories yet',
          message: 'Pull down to refresh, or check back in a few minutes.',
          icon: Icons.newspaper_outlined,
        ),
      );
    } else {
      content = _FeedSliver(
        feed: feed,
        localStories: localStories.value ?? const <Article>[],
      );
    }

    return SlPageScaffold(
      title: 'Top stories',
      brandMark: 'SLNews',
      onRefresh: ref.watch(refreshFeedsProvider),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: OfflineBanner(
            isOffline: offline.isOffline,
            lastSyncedAt: offline.lastSyncedAt,
          ),
        ),
        if (feed != null) ...<Widget>[
          // The weather/alert header is its own row above the title: on the
          // reference screen the title never competes with it for width.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: WeatherAlertHeader(
                location: feed.activeLocation,
                hasBreaking: feed.hasBreaking,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SlPageTitle(
              title: 'Top stories',
              onTap: () => context.go(AppRoutes.news),
            ),
          ),
        ],
        content,
      ],
    );
  }
}

/// Sync state of the article repository, read defensively so a bare
/// `ProviderScope` (widget test) cannot fail the page build.
class _OfflineStatus {
  const _OfflineStatus(this.isOffline, this.lastSyncedAt);

  final bool isOffline;
  final DateTime? lastSyncedAt;
}

_OfflineStatus _readOffline(WidgetRef ref) {
  try {
    // `read`, not `watch`: the banner must not rebuild on every repository
    // change, and the value is already re-read whenever the feed resolves.
    final ArticleRepository repository = ref.read(articleRepositoryProvider);
    return _OfflineStatus(repository.isOffline, repository.lastSyncedAt);
  } on UnimplementedError {
    return const _OfflineStatus(false, null);
  }
}

/// The populated feed, split into the carousel, the local stream and the rest.
class _FeedSliver extends ConsumerWidget {
  const _FeedSliver({required this.feed, required this.localStories});

  final ForYouFeed feed;
  final List<Article> localStories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> localIds = <String>{
      for (final Article article in localStories) article.id,
    };
    final List<Article> localStream = feed.stream
        .where((Article article) => localIds.contains(article.id))
        .toList(growable: false);
    final List<Article> latestStream = feed.stream
        .where((Article article) => !localIds.contains(article.id))
        .toList(growable: false);

    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: TopStoriesCarousel(
            articles: feed.hero,
            onOpenArticle: (Article article) =>
                context.push(AppRoutes.articleFor(article.id)),
          ),
        ),
        if (localStream.isNotEmpty) ...<Widget>[
          SliverToBoxAdapter(
            child: SectionHeader(title: 'From ${feed.activeLocation.label}'),
          ),
          _ArticleTileSliver(articles: localStream),
        ],
        if (latestStream.isNotEmpty) ...<Widget>[
          const SliverToBoxAdapter(child: SectionHeader(title: 'Latest')),
          _ArticleTileSliver(articles: latestStream),
        ],
      ],
    );
  }
}

/// A run of [ArticleTile]s with the reference UI's 12pt inter-card gap.
class _ArticleTileSliver extends ConsumerWidget {
  const _ArticleTileSliver({required this.articles});

  final List<Article> articles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> liked = ref.watch(likesControllerProvider);

    return SliverList.separated(
      itemCount: articles.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int index) {
        final Article article = articles[index];
        return Padding(
          padding: AppSpacing.page,
          child: ArticleTile(
            article: article,
            isLiked: liked.contains(article.id),
            onTap: () => context.push(AppRoutes.articleFor(article.id)),
            onLike: () =>
                ref.read(likesControllerProvider.notifier).toggle(article.id),
            onMore: (ArticleAction action) =>
                handleArticleAction(context, ref, article, action),
          ),
        );
      },
    );
  }
}

/// Loading state: one hero placeholder plus two tile placeholders.
class _FeedSkeletonSliver extends StatelessWidget {
  const _FeedSkeletonSliver();

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: HeroCardSkeleton(),
        ),
        for (int index = 0; index < 2; index++)
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: ArticleTileSkeleton(),
          ),
      ],
    );
  }
}
