import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/domain/models/ad_unit.dart';
import '../../../core/domain/models/app_settings.dart';
import '../../../core/domain/models/news_category.dart';
import '../../../core/domain/models/article.dart';
import '../../../core/domain/models/index_quote.dart';
import '../../../core/domain/models/sports_models.dart';
import '../../../core/domain/models/video_moment.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tracked_ad_card.dart';
import '../../../core/widgets/article_tile.dart';
import '../../../core/widgets/more_stories_link.dart';
import '../../../core/widgets/overflow_menu_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/sl_page_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import 'widgets/article_actions.dart';
import 'widgets/daily_briefing_card.dart';
import '../../markets/presentation/stocks_page.dart';
import '../../markets/presentation/widgets/stocks_card.dart';
import 'widgets/sport_spotlight_card.dart';
import 'widgets/top_stories_carousel.dart';
import 'widgets/topic_mosaic.dart';
import 'widgets/trending_now.dart';
import 'widgets/video_moments_rail.dart';
import 'widgets/weather_alert_header.dart';
import 'viewmodels/for_you_view_model.dart';

/// Tab 1 â€” the personalised "Top stories" feed.
///
/// Reconstructs the reference screen top to bottom: offline banner, weather and
/// breaking strip on the title row, the paged hero carousel, the local stream,
/// then the reference rails â€” Latest, an ad, Video moments, Picks for you, a
/// second ad and Your next read. All ordering, merging and de-duplication lives
/// in [ForYouViewModel] so this file only maps data to slivers.
class ForYouPage extends ConsumerWidget {
  const ForYouPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ForYouFeed? feed = ref.watch(forYouFeedProvider);
    final AsyncValue<List<Article>> topStories = ref.watch(topStoriesProvider);
    final AppSettings settings = ref.watch(settingsControllerProvider);
    final String locationId = settings.activeLocationId;
    final AsyncValue<List<Article>> localStories = ref.watch(
      locationFeedProvider(locationId),
    );
    // Both rails degrade to "absent" rather than erroring the page: video
    // moments fall back to the bundled rotation, ads may be empty.
    final List<VideoMoment> videos =
        ref.watch(videoMomentsProvider).value ?? const <VideoMoment>[];
    final List<AdUnit> ads =
        ref.watch(forYouAdsProvider).value ?? const <AdUnit>[];
    // Interactive content: the Stocks board only exists when the reader turned
    // that category on in Settings (on by default, as the reference shows the
    // finance card without being asked).
    final IndexBoard? indexBoard = ref.watch(indexBoardProvider).value;
    final List<GameScore> games =
        ref.watch(scoreboardProvider).value?.games ?? const <GameScore>[];

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
        videos: videos,
        ads: ads,
        indexBoard: indexBoard,
        showMarkets: settings.interactiveContentEnabled,
        games: games,
      );
    }

    return SlPageScaffold(
      title: 'Top stories',
      brandMark: 'SLNews',
      onRefresh: ref.watch(refreshFeedsProvider),
      slivers: <Widget>[
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
                // "Show weather forecast" in Settings hides the chip; a
                // breaking story still gets its tag.
                showWeather: settings.weatherForecastEnabled,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SlPageTitle(
              title: 'Top stories',
              // The reference opens a pushed section screen with a photo
              // header; the News tab is a separate destination.
              onTap: () => context.push(AppRoutes.topStories),
            ),
          ),
        ],
        content,
      ],
    );
  }
}

/// Slides the Stocks board up over the feed, as the reference does, instead of
/// pushing a full page. Deep links still reach `/stocks` directly.
Future<void> _openStocksPanel(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colors.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (BuildContext sheetContext) => const StocksPage(),
  );
}

/// The populated feed: carousel, local stream, then the reference screen's
/// rails â€” Latest, ad, Video moments, Picks for you, Your next read â€” with a
/// "More â€¦" link on the rails that lead somewhere.
class _FeedSliver extends ConsumerWidget {
  const _FeedSliver({
    required this.feed,
    required this.localStories,
    required this.videos,
    required this.ads,
    required this.indexBoard,
    required this.showMarkets,
    required this.games,
  });

  final ForYouFeed feed;
  final List<Article> localStories;
  final List<VideoMoment> videos;
  final List<AdUnit> ads;
  final IndexBoard? indexBoard;
  final bool showMarkets;
  final List<GameScore> games;

  /// Stories per rail. Four keeps every rail visible above the bottom bar on a
  /// 640dp-tall phone instead of turning the page into one long list.
  static const int railSize = 4;

  /// Four topic cards for the "Following" rail: the categories that have a
  /// usable story image first, so the mosaic never shows empty blocks above
  /// categories that do. Labels come from the curated category set.
  static List<TopicMosaicItem> _mosaicItems(
    ForYouFeed feed,
    List<Article> localStories,
  ) {
    final List<Article> all = <Article>[...feed.stream, ...localStories];
    final List<TopicMosaicItem> items = <TopicMosaicItem>[];
    for (final NewsCategory category in NewsCategories.all) {
      if (category.id == 'top') continue;
      String? imageUrl;
      for (final Article article in all) {
        final String? image = article.imageUrl?.trim();
        if (article.categoryId == category.id &&
            image != null &&
            image.isNotEmpty) {
          imageUrl = image;
          break;
        }
      }
      items.add(
        TopicMosaicItem(
          id: category.id,
          label: category.label,
          icon: category.icon,
          imageUrl: imageUrl,
        ),
      );
    }
    items.sort((TopicMosaicItem a, TopicMosaicItem b) {
      final bool aHas = a.imageUrl != null;
      final bool bHas = b.imageUrl != null;
      if (aHas == bHas) return 0;
      return aHas ? -1 : 1;
    });
    return items;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Local so the null check promotes inside the sliver list.
    final IndexBoard? board = indexBoard;

    final Set<String> localIds = <String>{
      for (final Article article in localStories) article.id,
    };
    final List<Article> localStream = feed.stream
        .where((Article article) => localIds.contains(article.id))
        .toList(growable: false);
    // Rails partition the remaining stories so the same headline never appears
    // twice on one screen.
    final List<Article> rest = feed.stream
        .where((Article article) => !localIds.contains(article.id))
        .toList(growable: false);
    final List<Article> latestStream = rest
        .take(railSize)
        .toList(growable: false);
    final List<Article> picks = rest
        .skip(railSize)
        .take(railSize)
        .toList(growable: false);
    final List<Article> nextRead = rest
        .skip(railSize * 2)
        .take(railSize)
        .toList(growable: false);

    // "Trending now" ranks only what the rails did not already show, so the same
    // headline never appears twice on one screen.
    final List<Article> trending = trendingArticles(
      rest.skip(railSize * 3).toList(growable: false),
    );

    // Briefing bullets: stories no rail on this screen already shows, so a
    // headline never appears twice.
    final Set<String> shownIds = <String>{
      for (final Article article in <Article>[
        ...feed.hero,
        ...localStream,
        ...latestStream,
        ...picks,
        ...nextRead,
        ...trending,
      ])
        article.id,
    };
    final List<Article> briefing = rest
        .where((Article article) => !shownIds.contains(article.id))
        .take(3)
        .toList(growable: false);

    final AdUnit? leadAd = ads.isNotEmpty ? ads.first : null;
    final AdUnit? secondAd = ads.length > 1 ? ads[1] : null;

    return SliverMainAxisGroup(
      slivers: <Widget>[
        if (briefing.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: DailyBriefingCard(
                title: briefingTitleFor(DateTime.now()),
                articles: briefing,
                onOpen: (Article article) =>
                    context.push(AppRoutes.articleFor(article.id)),
              ),
            ),
          ),
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
          SliverToBoxAdapter(
            child: MoreStoriesLink(
              label: 'More ${feed.activeLocation.label} stories',
              onPressed: () => context.go(AppRoutes.news),
            ),
          ),
        ],
        if (latestStream.isNotEmpty) ...<Widget>[
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Latest',
              onTap: () => context.go(AppRoutes.news),
              trailing: const _MoreLabel(),
            ),
          ),
          _ArticleTileSliver(articles: latestStream),
        ],
        if (_mosaicItems(feed, localStories).isNotEmpty) ...<Widget>[
          SliverToBoxAdapter(
            // "Following â€º" in the reference: the chevron comes from onTap, and
            // no "More" label, so the rail reads as a doorway rather than a list.
            child: SectionHeader(
              title: 'Following',
              onTap: () => context.go(AppRoutes.following),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TopicMosaic(
                items: _mosaicItems(feed, localStories),
                onOpen: (TopicMosaicItem item) => context.push(
                  AppRoutes.sectionFor(item.id),
                  extra: item.label,
                ),
              ),
            ),
          ),
        ],
        if (leadAd != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: TrackedAdCard(
                unit: leadAd,
                onCtaPressed: () => _openAd(context, leadAd),
                onOpened: (AdUnit unit) => _openAd(context, unit),
              ),
            ),
          ),
        if (videos.isNotEmpty) ...<Widget>[
          const SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Video moments',
              subtitle: "See what's new",
            ),
          ),
          SliverToBoxAdapter(
            child: VideoMomentsRail(
              videos: videos,
              onOpen: (VideoMoment video) => _openVideo(context, video),
            ),
          ),
        ],
        // Reference order: Trending now, then the Sports scoreboard card, then
        // the Stocks board. Each header chevron opens the full surface.
        if (trending.isNotEmpty) ...<Widget>[
          const SliverToBoxAdapter(child: SectionHeader(title: 'Trending now')),
          SliverToBoxAdapter(
            child: TrendingNow(
              articles: trending,
              onOpen: (Article article) =>
                  context.push(AppRoutes.articleFor(article.id)),
            ),
          ),
        ],
        if (games.isNotEmpty) ...<Widget>[
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Sports',
              subtitle: 'Scores and fixtures',
              onTap: () => context.go(AppRoutes.sports),
              trailing: const _MoreLabel(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SportSpotlightCard(
                game: games.first,
                onTap: () => context.go(AppRoutes.sports),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: MoreStoriesLink(
              label: 'More sports stories',
              onPressed: () => context.go(AppRoutes.sports),
            ),
          ),
        ],
        if (showMarkets && board != null && !board.isEmpty) ...<Widget>[
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Stocks',
              subtitle: board.isOpen ? 'Markets today' : 'Market closed',
              onTap: () => _openStocksPanel(context),
              trailing: const _MoreLabel(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: StocksCard(
                board: board,
                onOpen: () => _openStocksPanel(context),
              ),
            ),
          ),
        ],
        if (picks.isNotEmpty) ...<Widget>[
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Picks for you',
              subtitle: 'Articles you might enjoy',
              onTap: () => context.go(AppRoutes.news),
              trailing: const _MoreLabel(),
            ),
          ),
          _ArticleTileSliver(articles: picks),
        ],
        if (secondAd != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: TrackedAdCard(
                unit: secondAd,
                onCtaPressed: () => _openAd(context, secondAd),
                onOpened: (AdUnit unit) => _openAd(context, unit),
              ),
            ),
          ),
        if (nextRead.isNotEmpty) ...<Widget>[
          const SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Your next read',
              subtitle: 'Based on your interests',
            ),
          ),
          _ArticleTileSliver(articles: nextRead),
        ],
      ],
    );
  }

  /// Ads open their landing page when one is configured; the seed rotation has
  /// none, so the tap says so instead of doing nothing.
  Future<void> _openAd(BuildContext context, AdUnit unit) async {
    final String? target = unit.targetUrl;
    if (target == null || target.trim().isEmpty) {
      _snack(context, '${unit.advertiser}: ${unit.ctaLabel}');
      return;
    }
    final bool opened = await launchUrl(
      Uri.parse(target),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      _snack(context, 'Could not open the ad');
    }
  }

  void _openVideo(BuildContext context, VideoMoment video) {
    // In-app reel: handing the clip to the system browser left the app and broke
    // the reference's watch-then-swipe flow.
    context.push(AppRoutes.videoFor(video.id));
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// The small "More" affordance the reference puts beside a rail that continues
/// on another screen; the chevron itself comes from [SectionHeader].
class _MoreLabel extends StatelessWidget {
  const _MoreLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      'More',
      style: context.typography.meta.copyWith(
        color: context.colors.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
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
