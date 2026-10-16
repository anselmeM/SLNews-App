import 'package:flutter/material.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/sl_network_image.dart';

/// Featured image with its caption and credit line.
///
/// The image keeps a fixed 3:2 ratio so the reader never reflows while it
/// loads; when the story has no image the block collapses entirely instead of
/// leaving a grey hole.
class ArticleHeroMedia extends StatelessWidget {
  const ArticleHeroMedia({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final String? url = article.imageUrl;
    if (url == null || url.trim().isEmpty) return const SizedBox.shrink();

    final String? caption = article.imageCaption;
    final String? credit = article.imageCredit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 3 / 2,
          child: SlNetworkImage(
            url: url,
            borderRadius: AppRadius.imageRadius,
            placeholderLabel: article.publisher.mark,
          ),
        ),
        if (caption != null || credit != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                if (caption != null) TextSpan(text: caption),
                if (credit != null)
                  TextSpan(
                    text: ' | $credit',
                    style: context.typography.caption.copyWith(
                      color: context.colors.onSurfaceFaint,
                    ),
                  ),
              ],
            ),
            style: context.typography.caption,
          ),
        ],
      ],
    );
  }
}
