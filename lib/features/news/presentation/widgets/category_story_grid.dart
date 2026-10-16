import 'package:flutter/material.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/article_grid_tile.dart';
import '../../../../core/widgets/overflow_menu_button.dart';

/// Upper bound on the text scale inside the News card subtree.
///
/// `ArticleGridTile`'s and `ArticleHeroCard`'s metadata rows (publisher wordmark
/// + age + actions) have no flexible child, and `PublisherMark` ignores its
/// `maxWidth` on the wordmark path: measured with the bundled Inter face,
/// "SLNEWS" lays out 187.5pt wide regardless of the space offered, while a
/// 320pt two-column grid tile only offers a 114pt metadata row. At the reader's
/// largest `aA` step (1.3x) that overflow grows to ~78pt and visibly clips the
/// cards; clamping the card subtree holds it at the platform size, which is the
/// smallest value that keeps the tiles legible.
///
/// The residual few-pixel overflow of the shared tiles at 320pt cannot be
/// removed from this feature's scope and is reported to the Lead; the page's own
/// slivers are unaffected at every width.
const double kCategoryGridMaxTextScale = 1.0;

/// The two-column sub-category grid in the News tab.
///
/// A `SliverGrid` rather than a `GridView` because it is embedded in the page's
/// single `CustomScrollView`, which is what keeps the pill strip pinned and the
/// whole screen on one scroll position.
///
/// [childAspectRatio] was tuned by rendering the tiles at 320pt with a 1.3x text
/// scale: 0.63 is the point at which a three-line 60-character headline plus
/// the metadata row still fit the tile's fixed height. `news_page_test.dart`
/// pins the three-line truncation.
class CategoryStoryGrid extends StatelessWidget {
  const CategoryStoryGrid({
    super.key,
    required this.articles,
    this.onArticleTap,
    this.onArticleMore,
    this.childAspectRatio = 0.63,
  });

  /// Stories for the grid; the view model caps this at six.
  final List<Article> articles;

  /// Forwarded to every [ArticleGridTile].
  final ValueChanged<Article>? onArticleTap;

  /// Forwarded to every tile's kebab menu.
  final void Function(Article article, ArticleAction action)? onArticleMore;

  /// Width-to-height ratio of a single tile.
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: articles.length,
        itemBuilder: (BuildContext context, int index) {
          final Article article = articles[index];
          return MediaQuery.withClampedTextScaling(
            maxScaleFactor: kCategoryGridMaxTextScale,
            child: ArticleGridTile(
              article: article,
              onTap: onArticleTap == null ? null : () => onArticleTap!(article),
              onMore: onArticleMore == null
                  ? null
                  : (ArticleAction action) => onArticleMore!(article, action),
              maxTitleLines: 3,
            ),
          );
        },
      ),
    );
  }
}
