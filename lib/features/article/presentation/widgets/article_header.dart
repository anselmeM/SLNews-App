import 'package:flutter/material.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/time_ago.dart';
import '../../../../core/widgets/publisher_mark.dart';

/// Reader header: outlet attribution, headline, byline and publication time.
class ArticleHeader extends StatelessWidget {
  const ArticleHeader({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PublisherMark(publisher: article.publisher, logoHeight: 22, maxWidth: 200),
        const SizedBox(height: AppSpacing.lg),
        Text(article.title, style: context.typography.articleTitle),
        const SizedBox(height: AppSpacing.md),
        if (article.author != null && article.author!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text('By ${article.author}', style: context.typography.meta),
          ),
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                article.publishedAt.absoluteLabel,
                style: context.typography.meta.copyWith(color: context.colors.onSurfaceFaint),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '· ${article.estimatedReadingMinutes} min read',
              style: context.typography.meta.copyWith(color: context.colors.onSurfaceFaint),
            ),
          ],
        ),
      ],
    );
  }
}
