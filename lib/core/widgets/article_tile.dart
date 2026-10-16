import 'package:flutter/material.dart';

import '../domain/models/article.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'like_button.dart';
import 'overflow_menu_button.dart';
import 'publisher_mark.dart';
import 'sl_network_image.dart';

/// Compact feed card: text column on the left, thumbnail on the right.
///
/// This is the workhorse of the For You and News streams and mirrors the
/// reference layout: outlet mark, bold headline, timestamp bottom-left and the
/// like / overflow actions bottom-right inside the same white card.
class ArticleTile extends StatelessWidget {
  const ArticleTile({
    super.key,
    required this.article,
    this.onTap,
    this.onLike,
    this.onMore,
    this.isLiked = false,
    this.thumbnailWidth = 122,
    this.thumbnailHeight = 120,
    this.showPublisherMark = true,
    this.showSummary = false,
    this.showThumbnail = true,
  });

  final Article article;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final ValueChanged<ArticleAction>? onMore;
  final bool isLiked;
  final double thumbnailWidth;
  final double thumbnailHeight;
  final bool showPublisherMark;
  final bool showSummary;
  final bool showThumbnail;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${article.publisher.name}: ${article.title}',
      child: Material(
        color: context.colors.surface,
        borderRadius: AppRadius.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: AppSpacing.card,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (showPublisherMark) ...<Widget>[
                        PublisherMark(publisher: article.publisher, logoHeight: 17),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      Text(
                        article.title,
                        maxLines: showSummary ? 3 : 4,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.cardTitle,
                      ),
                      if (showSummary && article.summary.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          article.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.caption,
                        ),
                      ],
                      SizedBox(height: showSummary ? AppSpacing.md : AppSpacing.xl),
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              article.relativeAge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.typography.meta,
                            ),
                          ),
                          const Spacer(),
                          LikeButton(
                            isLiked: isLiked,
                            onPressed: onLike,
                            semanticLabel: 'Like ${article.title}',
                          ),
                          OverflowMenuButton(onSelected: onMore),
                        ],
                      ),
                    ],
                  ),
                ),
                if (showThumbnail) ...<Widget>[
                  const SizedBox(width: AppSpacing.lg),
                  SlNetworkImage(
                    url: article.imageUrl,
                    width: thumbnailWidth,
                    height: thumbnailHeight,
                    borderRadius: AppRadius.imageRadius,
                    placeholderLabel: article.publisher.mark,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
