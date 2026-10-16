import 'package:flutter/material.dart';

import '../domain/models/publisher.dart';
import '../theme/app_typography.dart';
import 'sl_network_image.dart';

/// Renders an outlet identity: the real logo when the feed supplies one,
/// otherwise its uppercase wordmark — exactly how the reference screens show
/// "NATIONAL POST" / "CBC NEWS" attribution lines.
class PublisherMark extends StatelessWidget {
  const PublisherMark({
    super.key,
    required this.publisher,
    this.logoHeight = 18,
    this.color,
    this.maxWidth = 160,
  });

  final Publisher publisher;
  final double logoHeight;

  /// Overrides the wordmark colour (used on hero-image scrims).
  final Color? color;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (publisher.logoUrl != null && publisher.logoUrl!.trim().isNotEmpty) {
      return SlNetworkImage(
        url: publisher.logoUrl,
        height: logoHeight,
        width: maxWidth,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        placeholderLabel: publisher.mark,
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text(
        publisher.mark,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: context.typography.publisherMark.copyWith(
          color: color ?? context.typography.primaryText,
        ),
      ),
    );
  }
}
