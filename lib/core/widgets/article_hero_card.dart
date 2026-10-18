import 'package:flutter/material.dart';

import '../domain/models/article.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'like_button.dart';
import 'overflow_menu_button.dart';
import 'publisher_mark.dart';
import 'pressable_ink_well.dart';
import 'sl_network_image.dart';

/// Full-bleed featured card used by the For You carousel and category heroes.
///
/// Layout contract (matches the reference screens):
/// rounded image, bottom-up scrim, headline over the image, then a meta row
/// with the outlet wordmark, "· 3 hours ago" and the like / overflow actions.
class ArticleHeroCard extends StatelessWidget {
  const ArticleHeroCard({
    super.key,
    required this.article,
    this.onTap,
    this.onLike,
    this.onMore,
    this.isLiked = false,
    this.height = 420,
    this.showPublisherMark = true,
    this.showSummary = false,
    this.margin = EdgeInsets.zero,
  });

  final Article article;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final ValueChanged<ArticleAction>? onMore;
  final bool isLiked;
  final double height;
  final bool showPublisherMark;
  final bool showSummary;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Semantics(
        button: true,
        label: '${article.publisher.name}: ${article.title}',
        child: Material(
          color: context.colors.surface,
          borderRadius: AppRadius.cardRadius,
          clipBehavior: Clip.antiAlias,
          child: PressableInkWell(
            onTap: onTap,
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  SlNetworkImage(
                    url: article.imageUrl,
                    placeholderLabel: article.publisher.mark,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Color(0x1A000000),
                          Color(0x40000000),
                          Color(0xD9000000),
                        ],
                        stops: <double>[0, 0.45, 1],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (article.isBreaking || article.isLive)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _BreakingTag(isLive: article.isLive),
                          ),
                        Text(
                          article.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.heroTitle,
                        ),
                        if (showSummary &&
                            article.summary.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            article.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.typography.meta.copyWith(
                              color: const Color(0xCCFFFFFF),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: <Widget>[
                            // The attribution owns what the actions do not use.
                            // A Spacer here would be flexible too, and the two
                            // would split the row: that is what turned a long
                            // outlet name into "SIERRA L…".
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  if (showPublisherMark)
                                    Flexible(
                                      child: PublisherMark(
                                        publisher: article.publisher,
                                        color: const Color(0xE6FFFFFF),
                                        logoHeight: 16,
                                      ),
                                    ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    '· ${article.relativeAge}',
                                    style: context.typography.meta.copyWith(
                                      color: const Color(0xCCFFFFFF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            LikeButton(
                              isLiked: isLiked,
                              onPressed: onLike,
                              size: 21,
                              semanticLabel: 'Like ${article.title}',
                            ),
                            OverflowMenuButton(
                              onSelected: onMore,
                              color: const Color(0xE6FFFFFF),
                              size: 21,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BreakingTag extends StatelessWidget {
  const _BreakingTag({required this.isLive});

  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: context.colors.live,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
      ),
      child: Text(
        isLive ? 'LIVE' : 'BREAKING',
        style: context.typography.overline.copyWith(color: Colors.white),
      ),
    );
  }
}
