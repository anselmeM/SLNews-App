import 'package:flutter/material.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/domain/models/news_category.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/time_ago.dart';
import '../../../../core/widgets/publisher_mark.dart';

/// Reader header: section label, outlet attribution, headline, byline and
/// publication line.
///
/// Layout follows the reference article page: a red section label, the outlet's
/// mark, the headline, "By …", then "Published: October 17, 2026 at 7:47 p.m.
/// EDT". Reading time sits under the date rather than beside it, so the long
/// "Published:" line never squeezes anything.
class ArticleHeader extends StatelessWidget {
  const ArticleHeader({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    // "Top stories" is the aggregator, not a section the reader picked, so it is
    // skipped instead of labelling every syndicated story with it.
    final String sectionLabel = NewsCategories.byId(article.categoryId).label;
    final bool showSection =
        article.categoryId != 'top' && sectionLabel.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showSection) ...<Widget>[
          Text(
            sectionLabel,
            style: context.typography.caption.copyWith(
              color: context.colors.live,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        PublisherMark(
          publisher: article.publisher,
          logoHeight: 22,
          maxWidth: 200,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(article.title, style: context.typography.articleTitle),
        const SizedBox(height: AppSpacing.md),
        if (article.author != null && article.author!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text('By ${article.author}', style: context.typography.meta),
          ),
        Text(
          article.publishedAt.publishedLabelWithZone,
          style: context.typography.meta.copyWith(
            color: context.colors.onSurfaceFaint,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '${article.estimatedReadingMinutes} min read',
          style: context.typography.meta.copyWith(
            color: context.colors.onSurfaceFaint,
          ),
        ),
      ],
    );
  }
}
