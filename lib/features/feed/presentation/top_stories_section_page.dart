import 'package:flutter/material.dart';
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
  const TopStoriesSectionPage({super.key});

  @override
  ConsumerState<TopStoriesSectionPage> createState() =>
      _TopStoriesSectionPageState();
}

class _TopStoriesSectionPageState extends ConsumerState<TopStoriesSectionPage> {
  final ScrollController _controller = ScrollController();
  bool _showToTop = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    final bool visible =
        _controller.hasClients &&
        _controller.offset > ScrollToTopButton.threshold;
    if (visible != _showToTop) setState(() => _showToTop = visible);
  }

  Future<void> _backToTop() async {
    if (!_controller.hasClients) return;
    await _controller.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Article>> stories = ref.watch(topStoriesProvider);
    final List<Article> articles = stories.value ?? const <Article>[];
    final Article? hero = articles.isEmpty ? null : articles.first;

    return Scaffold(
      backgroundColor: context.colors.canvas,
      body: Stack(
        children: <Widget>[
          CustomScrollView(
            controller: _controller,
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
                  background: _SectionHero(article: hero),
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
                    label: 'More top stories',
                    onPressed: () => context.go(AppRoutes.news),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxxl),
                ),
              ],
            ],
          ),
          if (_showToTop)
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.lg,
              child: Center(child: ScrollToTopButton(onPressed: _backToTop)),
            ),
        ],
      ),
    );
  }
}

/// Photo, scrim and section title for the collapsing header.
class _SectionHero extends StatelessWidget {
  const _SectionHero({required this.article});

  final Article? article;

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
            'Top stories',
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
