part of 'for_you_page.dart';

/// The populated feed: carousel, then the reference screen's rails — Latest,
/// ad, Video moments, Picks for you, Your next read — with a "More …" link on
/// the rails that lead somewhere.
class _FeedSliver extends ConsumerWidget {
  const _FeedSliver({
    required this.feed,
    required this.videos,
    required this.ads,
    required this.indexBoard,
    required this.showMarkets,
    required this.games,
  });

  final ForYouFeed feed;
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
  static List<TopicMosaicItem> _mosaicItems(ForYouFeed feed) {
    final List<Article> all = feed.stream;
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

    // Rails partition the stream so the same headline never appears twice.
    final List<Article> rest = feed.stream;
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
              padding: const EdgeInsets.only(top: AppSpacing.md),
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
        if (_mosaicItems(feed).isNotEmpty) ...<Widget>[
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
                items: _mosaicItems(feed),
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
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Video moments',
              subtitle: "See what's new",
              onTap: () => _openVideo(context, videos.first),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.play_circle_outline,
                    size: 17,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Watch all',
                    style: context.typography.caption.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
