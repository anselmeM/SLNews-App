import 'package:flutter/material.dart';
import 'package:slnews_mobile/core/widgets/scroll_to_top_state_mixin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ads/sponsorship_launcher.dart';
import '../../../core/domain/models/ad_placement.dart';
import '../../../core/domain/models/ad_unit.dart';
import '../../../core/domain/models/article.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/providers/reading_history_provider.dart';
import '../../../core/tts/tts_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/html_content.dart';
import '../../../core/widgets/publisher_mark.dart';
import '../../../core/widgets/tracked_ad_card.dart';
import '../../../core/widgets/scroll_to_top_button.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/article_web_mode.dart';
import 'widgets/article_action_bar.dart';
import 'widgets/reading_progress_bar.dart';
import 'widgets/article_header.dart';
import 'widgets/article_hero_media.dart';
import 'widgets/related_stories.dart';

/// The dedicated article reader (`/article/:id`).
///
/// Layout follows the CBC-style reference screen: the outlet's wordmark in the
/// bar, attribution and headline at the top, hero media with caption, then the
/// body, finished by the persistent floating action bar (follow publisher, `aA`,
/// like, translate, share, menu).
class ArticlePage extends ConsumerWidget {
  const ArticlePage({super.key, required this.articleId});

  final String articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Article?> article = ref.watch(articleProvider(articleId));

    return Scaffold(
      backgroundColor: context.colors.canvas,
      body: article.when(
        loading: () => const _ReaderSkeleton(),
        error: (Object error, StackTrace stackTrace) => SafeArea(
          child: ErrorStateView(
            message: "We couldn't open this story.",
            onRetry: () => ref.invalidate(articleProvider(articleId)),
          ),
        ),
        data: (Article? story) {
          if (story == null) {
            return SafeArea(
              child: EmptyStateView(
                title: 'Story unavailable',
                message: 'This story is no longer in your saved feed.',
                actionLabel: 'Back',
                onAction: () => context.pop(),
                icon: Icons.article_outlined,
              ),
            );
          }
          final List<String> history = ref.read(readingHistoryProvider);
          if (history.isEmpty || history.first != story.id) {
            // Record after the frame: the notifier writes preferences, which
            // must not happen during build.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(readingHistoryProvider.notifier).record(story.id);
            });
          }
          return _ReaderBody(article: story);
        },
      ),
      bottomNavigationBar: article.value == null
          ? null
          : FadeSlideIn(
              // Rises the short distance from the edge, once, when the reader
              // has something to act on.
              offset: -10,
              child: ArticleActionBar(article: article.value!),
            ),
    );
  }
}

class _ReaderBody extends ConsumerStatefulWidget {
  const _ReaderBody({required this.article});

  final Article article;

  @override
  ConsumerState<_ReaderBody> createState() => _ReaderBodyState();
}

class _ReaderBodyState extends ConsumerState<_ReaderBody>
    with ScrollToTopStateMixin<_ReaderBody> {
  @override
  double get scrollToTopThreshold => ScrollToTopButton.threshold;

  @override
  void dispose() {
    // Leaving the reader must not leave the phone talking.
    try {
      ref.read(articleTtsProvider.notifier).stop();
    } catch (_) {
      // The container may already be gone during teardown.
    }
    super.dispose();
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
        CustomScrollView(
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
                      ref.read(bookmarksControllerProvider).contains(article.id)
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
                  // Shown only when the outlet did not simply repeat the standfirst
                  // as the body's opening paragraph.
                  if (article.summary.isNotEmpty &&
                      !HtmlBlocks.opensWith(
                        article.bodyHtml,
                        article.summary,
                      )) ...<Widget>[
                    Text(article.summary, style: context.typography.lead),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  HtmlContent(html: article.bodyHtml),
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
