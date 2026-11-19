import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/legal_links.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Attribution and the "not advice" line that must travel with market data.
///
/// Yahoo's terms require attribution, and these indices are indicative quotes
/// rather than a trading feed, so the disclaimer sits next to the numbers instead
/// of only in the store listing. The source label is mapped to a human name so
/// the reader never sees the internal `yahoo/finance` tag.
class MarketDataNotice extends ConsumerWidget {
  const MarketDataNotice({
    super.key,
    this.sourceLabel = 'yahoo/finance',
    this.compact = false,
  });

  /// Internal label from [IndexBoard.sourceLabel].
  final String sourceLabel;

  /// Smaller type for the in-feed card; the page uses the default.
  final bool compact;

  /// Attribution target.
  static const String sourceUrl = 'https://finance.yahoo.com';

  /// Human name for an internal source label.
  static String friendlySource(String label) =>
      label.toLowerCase().contains('yahoo') ? 'Yahoo Finance' : label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextStyle style = context.typography.caption.copyWith(
      color: context.colors.onSurfaceFaint,
      fontSize: compact ? 10 : null,
    );
    final String source = friendlySource(sourceLabel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          link: true,
          label: 'Market data via $source. Opens Yahoo Finance.',
          child: InkWell(
            onTap: () => ref.read(externalUrlOpenerProvider)(sourceUrl),
            borderRadius: AppRadius.pillRadius,
            child: Text(
              'Market data via $source',
              style: style.copyWith(decoration: TextDecoration.underline),
            ),
          ),
        ),
        SizedBox(height: compact ? 1 : AppSpacing.xxs),
        Text(
          'Not investment advice. Quotes may be delayed or indicative.',
          style: style,
        ),
      ],
    );
  }
}
