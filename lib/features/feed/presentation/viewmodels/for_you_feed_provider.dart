part of 'for_you_view_model.dart';

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
