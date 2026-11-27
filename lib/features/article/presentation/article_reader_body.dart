part of 'article_page.dart';

class _ReaderBody extends ConsumerStatefulWidget {
  const _ReaderBody({required this.article, this.initialProgress});

  final Article article;
  final double? initialProgress;

  @override
  ConsumerState<_ReaderBody> createState() => _ReaderBodyState();
}

class _ReaderBodyState extends ConsumerState<_ReaderBody>
    with ScrollToTopStateMixin<_ReaderBody>, WidgetsBindingObserver {
  DateTime? _openedAt;
  ProviderContainer? _profileContainer;
  String? _profileAccountKey;
  int? _profileGeneration;
  bool _profileEnabled = true;
  int _restoreAttempts = 0;
  double _lastProgress = 0;
  Duration _backgroundDuration = Duration.zero;
  DateTime? _backgroundStarted;

  @override
  double get scrollToTopThreshold => ScrollToTopButton.threshold;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileContainer != null) return;
    try {
      _profileContainer = ProviderScope.containerOf(context);
      _profileAccountKey = _accountKey(ref);
      _profileGeneration = _profileGenerationOf(ref);
      _profileEnabled = _personalizationEnabled(ref);
    } catch (_) {
      // No provider scope (for example a very narrow widget test harness).
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openedAt = DateTime.now();
    scrollController.addListener(_captureScrollProgress);
    _restoreInitialProgress();
    _scheduleFitMeasurement();
    // Record the open after the frame: provider mutation during initState can
    // race the first build in Riverpod.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted || !_profileEnabled) return;
      try {
        ref
            .read(personalizationProfileProvider.notifier)
            .recordOpen(
              widget.article,
              accountKey: _profileAccountKey,
              generation: _profileGeneration,
            );
      } catch (_) {
        // Personalization is best-effort and must never affect reading.
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scrollController.removeListener(_captureScrollProgress);
    final DateTime? openedAt = _openedAt;
    if (openedAt != null) {
      try {
        final ProviderContainer? container = _profileContainer;
        final bool enabled = container == null
            ? _profileEnabled
            : _personalizationEnabledContainer(container);
        if (container != null && enabled) {
          container
              .read(personalizationProfileProvider.notifier)
              .recordRead(
                widget.article,
                dwell: _foregroundDwell(openedAt),
                progress: _finalProgress(),
                accountKey: _profileAccountKey,
                generation: _profileGeneration,
              );
        }
      } catch (_) {
        // The container may already be gone during teardown.
      }
    }
    // Leaving the reader must not leave the phone talking.
    try {
      ref.read(articleTtsProvider.notifier).stop();
    } catch (_) {
      // The container may already be gone during teardown.
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final DateTime now = DateTime.now();
    if (state == AppLifecycleState.resumed) {
      final DateTime? started = _backgroundStarted;
      if (started != null) {
        _backgroundDuration += now.difference(started);
        _backgroundStarted = null;
      }
      return;
    }
    _backgroundStarted ??= now;
  }

  Duration _foregroundDwell(DateTime openedAt) {
    final DateTime now = DateTime.now();
    Duration background = _backgroundDuration;
    final DateTime? started = _backgroundStarted;
    if (started != null) background += now.difference(started);
    final Duration elapsed = now.difference(openedAt) - background;
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  void _restoreInitialProgress() {
    final double? saved = widget.initialProgress;
    if (saved == null || saved <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;
      if (!scrollController.hasClients) {
        _restoreInitialProgress();
        return;
      }
      final double max = scrollController.position.maxScrollExtent;
      if (max <= 0) {
        if (++_restoreAttempts < 8) {
          _restoreInitialProgress();
          SchedulerBinding.instance.scheduleFrame();
        }
        return;
      }
      scrollController.jumpTo((max * saved).clamp(0.0, max));
    });
  }

  /// Scroll progress at close. An article shorter than the viewport counts as
  /// fully read rather than as 0%.
  double _finalProgress() {
    if (!scrollController.hasClients) {
      // The controller can already be detached during teardown. Use the last
      // observed position rather than assuming the article was completed.
      return _lastProgress;
    }
    final double max = scrollController.position.maxScrollExtent;
    if (max <= 0) return 1; // Article fits without scrolling: fully read.
    return (scrollController.offset / max).clamp(0.0, 1.0).toDouble();
  }

  void _captureScrollProgress() {
    if (!scrollController.hasClients) return;
    final double max = scrollController.position.maxScrollExtent;
    if (max <= 0) return; // Fits check is handled after layout settles.
    _lastProgress = (scrollController.offset / max).clamp(0.0, 1.0).toDouble();
  }

  void _scheduleFitMeasurement([int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;
      if (!scrollController.hasClients) {
        if (attempt < 8) {
          _scheduleFitMeasurement(attempt + 1);
          SchedulerBinding.instance.scheduleFrame();
        }
        return;
      }
      if (scrollController.position.maxScrollExtent > 0) return;
      if (attempt < 3) {
        _scheduleFitMeasurement(attempt + 1);
        SchedulerBinding.instance.scheduleFrame();
        return;
      }
      _lastProgress = 1;
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    final ScrollMetrics metrics = notification.metrics;
    if (metrics.maxScrollExtent <= 0) return false;
    _lastProgress = (metrics.pixels / metrics.maxScrollExtent)
        .clamp(0.0, 1.0)
        .toDouble();
    return false;
  }

  @override
  bool get tracksReadingProgress => true;

  @override
  double readingProgress(ScrollController controller) =>
      readingProgressFor(controller);

  @override
  Widget build(BuildContext context) {
    final Article article = widget.article;
    final List<Article> related =
        ref
            .watch(categoryFeedProvider(article.categoryId))
            .value
            ?.where((Article candidate) => candidate.id != article.id)
            .take(4)
            .toList(growable: false) ??
        const <Article>[];

    // The reference reader floats the back-to-top control over the body once the
    // story is scrolled, exactly like the feeds.
    return Stack(
      children: <Widget>[
        NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: CustomScrollView(
            controller: scrollController,
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                toolbarHeight: 72,
                titleSpacing: AppSpacing.xl,
                backgroundColor: context.colors.canvas,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                  onPressed: () => context.pop(),
                ),
                // The reference reader puts the outlet's own wordmark in the bar,
                // not a plain text name: PublisherMark draws the logo when the outlet
                // has one and its brand wordmark otherwise.
                title: PublisherMark(
                  publisher: article.publisher,
                  logoHeight: 22,
                  maxWidth: 150,
                  color: context.colors.onSurfaceVariant,
                ),
                centerTitle: true,
                actions: <Widget>[
                  if (ArticleWebMode.originalAction(article.sourceUrl) !=
                      ArticleOriginalAction.none)
                    IconButton(
                      icon: const Icon(Icons.public),
                      tooltip: 'Read original',
                      onPressed: () => _openOriginal(context, article),
                    ),
                  IconButton(
                    icon: const Icon(Icons.bookmark_border),
                    tooltip: 'Save story',
                    onPressed: () {
                      ref
                          .read(bookmarksControllerProvider.notifier)
                          .toggle(article.id);
                      _showSnack(
                        context,
                        ref
                                .read(bookmarksControllerProvider)
                                .contains(article.id)
                            ? 'Saved'
                            : 'Removed from saved',
                      );
                    },
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
              ),
              SliverPadding(
                padding: AppSpacing.page,
                sliver: SliverList.list(
                  children: <Widget>[
                    ArticleHeader(article: article),
                    const SizedBox(height: AppSpacing.lg),
                    ArticleHeroMedia(article: article),
                    const SizedBox(height: AppSpacing.xl),
                    if (article.previewOnly)
                      _PreviewStoryCard(
                        article: article,
                        onReadFullStory: () => _openOriginal(context, article),
                      )
                    else ...<Widget>[
                      // Shown only when the outlet did not simply repeat the
                      // standfirst as the body's opening paragraph.
                      if (article.summary.isNotEmpty &&
                          !HtmlBlocks.opensWith(
                            article.bodyHtml,
                            article.summary,
                          )) ...<Widget>[
                        Text(article.summary, style: context.typography.lead),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      HtmlContent(html: article.bodyHtml),
                    ],
                    if (article.tags.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          for (final String tag in article.tags)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs + 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.surfaceMuted,
                                borderRadius: AppRadius.pillRadius,
                              ),
                              child: Text(
                                '#$tag',
                                style: context.typography.caption,
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    const _ArticleEndAd(),
                    const SizedBox(height: AppSpacing.xxl),
                    RelatedStories(articles: related),
                    const SizedBox(height: AppSpacing.xxxl),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + kToolbarHeight,
          left: 0,
          right: 0,
          child: ReadingProgressBar(progress: scrollProgress),
        ),
        if (showScrollToTopButton)
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.md,
            child: Center(child: ScrollToTopButton(onPressed: scrollToTop)),
          ),
      ],
    );
  }

  Future<void> _openOriginal(BuildContext context, Article article) async {
    final ArticleOriginalAction action = ArticleWebMode.originalAction(
      article.sourceUrl,
    );
    if (action == ArticleOriginalAction.inApp) {
      context.push('${AppRoutes.articleFor(article.id)}/original');
      return;
    }
    if (action != ArticleOriginalAction.external) return;

    final Uri? uri = Uri.tryParse(article.sourceUrl ?? '');
    if (uri == null) return;
    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        _showSnack(context, 'Could not open the link');
      }
    } catch (_) {
      if (context.mounted) _showSnack(context, 'Could not open the link');
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }
}

/// Reader card for a story whose publisher has not licensed full-text
/// republication. It shows the excerpt and one clear hand-off to the publisher.
class _PreviewStoryCard extends StatelessWidget {
  const _PreviewStoryCard({
    required this.article,
    required this.onReadFullStory,
  });

  final Article article;
  final VoidCallback onReadFullStory;

  @override
  Widget build(BuildContext context) {
    final String? sourceUrl = article.sourceUrl?.trim();
    final bool canOpen = sourceUrl != null && sourceUrl.isNotEmpty;
    final String excerpt = article.summary.trim().isNotEmpty
        ? article.summary.trim()
        : 'This story is available at ${article.publisher.name}.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.article_outlined,
                size: 18,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Preview',
                style: context.typography.caption.copyWith(
                  color: context.colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(excerpt, style: context.typography.lead),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Full story at ${article.publisher.name}.',
            style: context.typography.caption.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canOpen ? onReadFullStory : null,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Read full story'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reader placeholder that reserves the real layout's geometry.
class _ReaderSkeleton extends StatelessWidget {
  const _ReaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

/// The `article_end` sold placement, rendered after the story body and before
/// related stories. The provider is allowed to fail or stay empty: an ad must
/// never break reading.
class _ArticleEndAd extends ConsumerWidget {
  const _ArticleEndAd();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AdUnit> units =
        ref.watch(adUnitsProvider(AdPlacement.articleEnd.wire)).asData?.value ??
        const <AdUnit>[];
    if (units.isEmpty) return const SizedBox.shrink();
    final AdUnit unit = units.first;
    return TrackedAdCard(
      unit: unit,
      onCtaPressed: () => openSponsorship(context, ref, unit),
      onOpened: (AdUnit opened) => openSponsorship(context, ref, opened),
    );
  }
}
