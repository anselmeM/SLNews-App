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
    // Rights posture: every image carries a credit. When the feed or the page
    // does not supply one, attribute it to the publisher we took it from.
    final String creditLine = _creditLine(article);

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
        const SizedBox(height: AppSpacing.sm),
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              if (caption != null) TextSpan(text: '$caption | '),
              TextSpan(
                text: creditLine,
                style: context.typography.caption.copyWith(
                  color: context.colors.onSurfaceFaint,
                ),
              ),
            ],
          ),
          style: context.typography.caption,
        ),
      ],
    );
  }

  /// "Photo: Reuters" from a supplied credit, otherwise the publisher name.
  static String _creditLine(Article article) {
    final String? credit = article.imageCredit?.trim();
    if (credit == null || credit.isEmpty) {
      return 'Photo: ${article.publisher.name}';
    }
    return credit.toLowerCase().startsWith('photo') ? credit : 'Photo: $credit';
  }
}
