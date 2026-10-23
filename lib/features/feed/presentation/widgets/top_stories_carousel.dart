import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/providers/controllers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/article_hero_card.dart';
import '../../../../core/widgets/overflow_menu_button.dart';
import 'article_actions.dart';

/// Horizontally paged hero carousel for the For You lead stories.
///
/// A `PageView` (rather than a list) is what reproduces the reference screens'
/// snap-to-card behaviour; the dots underneath are the only local state.
class TopStoriesCarousel extends ConsumerStatefulWidget {
  const TopStoriesCarousel({
    super.key,
    required this.articles,
    this.onOpenArticle,
    this.height = 380,
  });

  /// Lead stories, already ordered by the For You view model.
  final List<Article> articles;

  /// Navigation callback; the page owns routing so this stays testable.
  final ValueChanged<Article>? onOpenArticle;

  final double height;

  @override
  ConsumerState<TopStoriesCarousel> createState() => _TopStoriesCarouselState();
}

class _TopStoriesCarouselState extends ConsumerState<TopStoriesCarousel> {
  /// 0.94 leaves a sliver of the next card visible, as in the reference UI.
  static const double _viewportFraction = 0.94;

  late final PageController _controller = PageController(
    viewportFraction: _viewportFraction,
  );
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Article> articles = widget.articles;
    if (articles.isEmpty) return const SizedBox.shrink();

    final Set<String> liked = ref.watch(likesControllerProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: articles.length,
            onPageChanged: (int page) => setState(() => _page = page),
            itemBuilder: (BuildContext context, int index) {
              final Article article = articles[index];
              final Widget card = Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: ArticleHeroCard(
                  article: article,
                  height: widget.height,
                  isLiked: liked.contains(article.id),
                  onTap: () => widget.onOpenArticle?.call(article),
                  onLike: () => ref
                      .read(likesControllerProvider.notifier)
                      .toggle(article.id),
                  onMore: (ArticleAction action) =>
                      handleArticleAction(context, ref, article, action),
                ),
              );
              // Neighbours sit slightly smaller and dimmer, so a swipe reads as
              // motion rather than a jump cut.
              return AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? child) {
                  double distance = 0;
                  if (_controller.hasClients &&
                      _controller.position.haveDimensions) {
                    final double page = _controller.page ?? _page.toDouble();
                    distance = (page - index).abs().clamp(0.0, 1.0);
                  }
                  return Transform.scale(
                    scale: 1 - distance * 0.05,
                    child: Opacity(opacity: 1 - distance * 0.35, child: child),
                  );
                },
                child: card,
              );
            },
          ),
        ),
        if (articles.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: _PageDots(count: articles.length, index: _page),
          ),
      ],
    );
  }
}

/// Page-indicator dots; the active dot is the full-contrast surface colour.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Page ${index + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (int dot = 0; dot < count; dot++)
            AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: dot == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: dot == index
                    ? context.colors.onSurface
                    : context.colors.onSurfaceFaint,
                borderRadius: AppRadius.pillRadius,
              ),
            ),
        ],
      ),
    );
  }
}
