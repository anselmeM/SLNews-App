import 'package:flutter/material.dart';
import 'package:slnews_mobile/core/widgets/scroll_to_top_state_mixin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/article.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/article_tile.dart';
import '../../../core/widgets/more_stories_link.dart';
import '../../../core/widgets/scroll_to_top_button.dart';
import '../../../core/widgets/sl_network_image.dart';
import '../../../core/widgets/state_views.dart';

/// The pushed "Top stories" screen from the reference: the section title sits over
/// the lead story's photo in a collapsing header, then the story list, with a
/// floating back-to-top control once the reader scrolls.
///
/// Tapping the For You title lands here instead of jumping to the News tab, which
/// is what makes the header chevron behave like a "see all" on the reference.
class TopStoriesSectionPage extends ConsumerStatefulWidget {
  const TopStoriesSectionPage({
    super.key,
    this.categoryId,
    this.title = 'Top stories',
  });

  /// When set, the page lists that category's stories instead of Top stories.
  final String? categoryId;

  /// Header title; also used by the "More …" link at the end of the list.
  final String title;

  /// Readable title for a section id, used when a deep link carries no label.
  static String titleFromId(String id) {
    final String raw = id.contains(':') ? id.split(':').last : id;
    final String spaced = raw.replaceAll(RegExp(r'[-_]'), ' ');
    if (spaced.isEmpty) return 'Section';
    return spaced
        .split(' ')
        .where((String word) => word.isNotEmpty)
        .map(
          (String word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  @override
  ConsumerState<TopStoriesSectionPage> createState() =>
      _TopStoriesSectionPageState();
}

class _TopStoriesSectionPageState extends ConsumerState<TopStoriesSectionPage>
    with ScrollToTopStateMixin<TopStoriesSectionPage> {
  @override
  double get scrollToTopThreshold => ScrollToTopButton.threshold;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Article>> stories = widget.categoryId == null
        ? ref.watch(topStoriesProvider)
        : ref.watch(categoryFeedProvider(widget.categoryId!));
    final List<Article> articles = stories.value ?? const <Article>[];
    final Article? hero = articles.isEmpty ? null : articles.first;

    return Scaffold(
      backgroundColor: context.colors.canvas,
      body: Stack(
        children: <Widget>[
          CustomScrollView(
            controller: scrollController,
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                expandedHeight: 240,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: context.colors.canvas,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: _SectionHero(article: hero, title: widget.title),
                ),
              ),
              if (stories.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorStateView(
                    onRetry: () => ref.invalidate(topStoriesProvider),
                  ),
                )
              else if (!stories.hasValue)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (articles.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateView(
                    title: 'No stories yet',
                    message:
                        'Nothing has been published in ${widget.title} yet.',
                    icon: Icons.article_outlined,
                  ),
                )
              else ...<Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  sliver: SliverList.list(
                    children: <Widget>[
                      for (final Article article in articles)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ArticleTile(
                            article: article,
                            onTap: () =>
                                context.push(AppRoutes.articleFor(article.id)),
                          ),
                        ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: MoreStoriesLink(
                    label: widget.categoryId == null
                        ? 'More top stories'
                        : 'More ${widget.title} stories',
                    onPressed: () => context.go(AppRoutes.news),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxxl),
                ),
              ],
            ],
          ),
          if (showScrollToTopButton)
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.lg,
              child: Center(child: ScrollToTopButton(onPressed: scrollToTop)),
            ),
        ],
      ),
    );
  }
}

/// Photo, scrim and section title for the collapsing header.
class _SectionHero extends StatelessWidget {
  const _SectionHero({required this.article, required this.title});

  final Article? article;
  final String title;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = article?.imageUrl ?? '';
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (imageUrl.trim().isNotEmpty)
          SlNetworkImage(
            url: imageUrl,
            placeholderLabel: article?.publisher.mark,
          )
        else
          ColoredBox(color: context.colors.surfaceMuted),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x33000000),
                Color(0x00000000),
                Color(0xB3000000),
              ],
              stops: <double>[0, 0.45, 1],
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: AppSpacing.md,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typography.sectionTitle.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              shadows: const <Shadow>[
                Shadow(color: Color(0x8A000000), blurRadius: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
