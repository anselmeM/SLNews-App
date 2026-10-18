import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/domain/models/ad_unit.dart';
import '../../../core/domain/models/app_settings.dart';
import '../../../core/domain/models/article.dart';
import '../../../core/domain/models/market_snapshot.dart';
import '../../../core/domain/models/sports_models.dart';
import '../../../core/domain/models/video_moment.dart';
import '../../../core/domain/repositories/article_repository.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ad_card.dart';
import '../../../core/widgets/article_tile.dart';
import '../../../core/widgets/overflow_menu_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/sl_page_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../markets/presentation/widgets/markets_sheet.dart';
import 'widgets/article_actions.dart';
import 'widgets/sports_carousel.dart';
import 'widgets/stocks_carousel.dart';
import 'widgets/top_stories_carousel.dart';
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
    // Interactive content: the Stocks section only exists when the reader turned
    // that category on in Settings (on by default, as the reference shows the
    // finance card without being asked).
    final MarketSnapshot? markets = ref.watch(marketSnapshotProvider).value;
    final List<GameScore> games =
        ref.watch(scoreboardProvider).value?.games ?? const <GameScore>[];
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
        videos: videos,
        ads: ads,
        markets: markets,
        showMarkets: settings.interactiveContentEnabled,
        games: games,
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
                // "Show weather forecast" in Settings hides the chip; a
                // breaking story still gets its tag.
                showWeather: settings.weatherForecastEnabled,
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

/// The populated feed: carousel, local stream, then the reference screen's
/// rails â€” Latest, ad, Video moments, Picks for you, Your next read â€” with a
/// "More â€¦" link on the rails that lead somewhere.
class _FeedSliver extends ConsumerWidget {
  const _FeedSliver({
    required this.feed,
    required this.localStories,
    required this.videos,
    required this.ads,
    required this.markets,
    required this.showMarkets,
    required this.games,
  });

  final ForYouFeed feed;
  final List<Article> localStories;
  final List<VideoMoment> videos;
  final List<AdUnit> ads;
  final MarketSnapshot? markets;
  final bool showMarkets;
  final List<GameScore> games;

  /// Stories per rail. Four keeps every rail visible above the bottom bar on a
  /// 640dp-tall phone instead of turning the page into one long list.
  static const int railSize = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Local so the null check promotes inside the sliver list.
    final MarketSnapshot? board = markets;

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

    final AdUnit? leadAd = ads.isNotEmpty ? ads.first : null;
    final AdUnit? secondAd = ads.length > 1 ? ads[1] : null;

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
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Latest',
              onTap: () => context.go(AppRoutes.news),
              trailing: const _MoreLabel(),
            ),
          ),
          _ArticleTileSliver(articles: latestStream),
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
              child: AdCard(
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
        // Sports and Stocks repeat the lead carousel's behaviour: a snap-to-card
        // pager with dots, and a header chevron that opens the full surface.
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
            child: SportsCarousel(
              games: games,
              onOpen: (GameScore _) => context.go(AppRoutes.sports),
            ),
          ),
        ],
        if (showMarkets && board != null && !board.isEmpty) ...<Widget>[
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Stocks',
              subtitle: 'Markets today',
              onTap: () => showMarketsSheet(context, snapshot: board),
              trailing: const _MoreLabel(),
            ),
          ),
          SliverToBoxAdapter(
            child: StocksCarousel(
              rates: board.board,
              onOpen: (MarketRate _) =>
                  showMarketsSheet(context, snapshot: board),
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
              child: AdCard(
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
