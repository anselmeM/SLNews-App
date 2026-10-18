import 'package:flutter/material.dart';

import '../domain/models/article.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'overflow_menu_button.dart';
import 'publisher_mark.dart';
import 'pressable_ink_well.dart';
import 'sl_network_image.dart';

/// Vertical card used by the two-column sub-category grid in the News tab.
///
/// Image on top, headline and attribution below, inside the same rounded
/// surface as the list cards so the grid and the list read as one system.
///
/// The layout is deliberately elastic: the grid cell height is fixed by the
/// sliver grid's aspect ratio, and with a 1.3x text scale a three-line headline
/// plus the attribution row is taller than the cell. The headline and the
/// attribution row are therefore both flexible, so text truncates instead of
/// overflowing at narrow widths (verified at 320 pt / 1.3x).
class ArticleGridTile extends StatelessWidget {
  const ArticleGridTile({
    super.key,
    required this.article,
    this.onTap,
    this.onMore,
    this.imageAspectRatio = 16 / 10,
    this.maxTitleLines = 3,
  });

  final Article article;
  final VoidCallback? onTap;
  final ValueChanged<ArticleAction>? onMore;
  final double imageAspectRatio;
  final int maxTitleLines;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${article.publisher.name}: ${article.title}',
      child: Material(
        color: context.colors.surface,
        borderRadius: AppRadius.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: PressableInkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AspectRatio(
                aspectRatio: imageAspectRatio,
                child: SlNetworkImage(
                  url: article.imageUrl,
                  placeholderLabel: article.publisher.mark,
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          article.title,
                          maxLines: maxTitleLines,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.cardTitleSmall,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: PublisherMark(
                              publisher: article.publisher,
                              logoHeight: 14,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              article.relativeAge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: context.typography.meta,
                            ),
                          ),
                          OverflowMenuButton(onSelected: onMore, size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
