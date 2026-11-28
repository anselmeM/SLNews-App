import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ads/sponsorship_launcher.dart';
import '../../../core/widgets/header_actions.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/ad_unit.dart';
import '../../../core/domain/models/app_settings.dart';
import '../../../core/domain/models/news_category.dart';
import '../../../core/domain/models/article.dart';
import '../../../core/domain/models/index_quote.dart';
import '../../../core/domain/models/sports_models.dart';
import '../../../core/domain/models/video_moment.dart';
import '../../../core/providers/aggregate_metrics.dart';
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
import '../../../core/widgets/store_widget.dart';
import '../../../core/widgets/state_views.dart';
import 'widgets/article_actions.dart';
import 'widgets/breaking_alert_banner.dart';
import 'widgets/continue_reading_rail.dart';
import '../../markets/presentation/stocks_page.dart';
import '../../markets/presentation/widgets/stocks_card.dart';
import 'widgets/sport_spotlight_card.dart';
import 'widgets/top_stories_carousel.dart';
import 'widgets/topic_mosaic.dart';
import 'widgets/trending_now.dart';
import 'widgets/video_moments_rail.dart';
import 'widgets/weather_briefing_card.dart';
import 'viewmodels/for_you_view_model.dart';

part 'feed_slivers.dart';

/// Tab 1 â€” the personalised "Top stories" feed.
///
/// Reconstructs the reference screen top to bottom: offline banner, weather and
/// weather row and dismissible breaking alert, the paged hero carousel, the local stream,
/// then the reference rails â€” Latest, an ad, Video moments, Picks for you, a
/// second ad and Your next read. All ordering, merging and de-duplication lives
/// in [ForYouViewModel] so this file only maps data to slivers.
class ForYouPage extends ConsumerWidget {
  const ForYouPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ForYouFeed? feed = ref.watch(forYouFeedProvider);
    if (feed != null) {
      unawaited(
        syncStoreWidget(
          top: feed.hero.isEmpty ? null : feed.hero.first,
          breakingCount: feed.breakingCount,
        ),
      );
      final List<Article> impressions = <Article>[
        ...feed.hero,
        ...feed.followingStories,
        ...feed.stream,
      ];
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (!context.mounted) return;
        try {
          ref
              .read(aggregateMetricsProvider.notifier)
              .recordImpressions(impressions);
        } catch (_) {
          // Diagnostics must never affect rendering.
        }
      });
    }
    final AsyncValue<List<Article>> topStories = ref.watch(topStoriesProvider);
    final AppSettings settings = ref.watch(settingsControllerProvider);
    // Both rails degrade to "absent" rather than erroring the page: video
    // moments fall back to the bundled rotation, ads may be empty.
    final List<VideoMoment> videos = ref.watch(videoMomentsProvider);
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
      actions: const <Widget>[HeaderActions()],
      onRefresh: ref.watch(refreshFeedsProvider),
      slivers: <Widget>[
        if (feed != null) ...<Widget>[
          // Breaking is editorial and separate from weather: a dismissible
          // alert row, never a permanent tag inside the weather section.
          if (feed.breakingAlert != null)
            SliverToBoxAdapter(
              child: BreakingAlertBanner(
                key: ValueKey<String>(feed.breakingAlert!.id),
                article: feed.breakingAlert!,
                onOpen: () =>
                    context.push(AppRoutes.articleFor(feed.breakingAlert!.id)),
              ),
            ),
          SliverToBoxAdapter(
            child: WeatherBriefingCard(
              showWeather: settings.weatherForecastEnabled,
              briefing: feed.briefing,
              onOpenArticle: (Article article) =>
                  context.push(AppRoutes.articleFor(article.id)),
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
