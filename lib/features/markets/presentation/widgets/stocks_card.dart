import 'package:flutter/material.dart';

import '../../../../core/domain/models/index_quote.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/time_ago.dart';
import '../../../../core/widgets/pressable_ink_well.dart';
import 'market_data_notice.dart';
import 'sparkline.dart';

/// The Stocks section of the For You feed: index rows in one card, with the
/// board's attribution underneath.
///
/// The reference renders this as a compact board (name, trend line, price and
/// percentage move per row) that opens the full Stocks page, so the card is a
/// summary and never pretends to be the whole surface.
class StocksCard extends StatelessWidget {
  const StocksCard({
    super.key,
    required this.board,
    this.onOpen,
    this.maxRows = 4,
  });

  final IndexBoard board;
  final VoidCallback? onOpen;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final List<IndexQuote> rows = board.quotes
        .take(maxRows)
        .toList(growable: false);
    if (rows.isEmpty) return const SizedBox.shrink();

    return Semantics(
      button: onOpen != null,
      label: 'Stocks board, ${rows.length} indices',
      child: PressableInkWell(
        onTap: onOpen,
        borderRadius: AppRadius.cardRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: AppRadius.cardRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int index = 0; index < rows.length; index++) ...<Widget>[
                  if (index > 0)
                    Divider(
                      height: AppSpacing.md,
                      color: context.colors.divider,
                    ),
                  IndexQuoteRow(quote: rows[index]),
                ],
                Divider(height: AppSpacing.lg, color: context.colors.divider),
                _BoardFooter(board: board),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One index line: label, trend, price and move. Shared with the Stocks page.
class IndexQuoteRow extends StatelessWidget {
  const IndexQuoteRow({
    super.key,
    required this.quote,
    this.sparklineWidth = 56,
    this.sparklineHeight = 22,
  });

  final IndexQuote quote;
  final double sparklineWidth;
  final double sparklineHeight;

  @override
  Widget build(BuildContext context) {
    final Color trend = quote.isUp
        ? context.colors.trendUp
        : context.colors.trendDown;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                quote.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.cardTitleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (quote.subtitle.isNotEmpty) ...<Widget>[
                const SizedBox(height: 1),
                Text(
                  quote.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.caption.copyWith(
                    color: context.colors.onSurfaceFaint,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Sparkline(
          points: quote.sparkline,
          isUp: quote.isUp,
          width: sparklineWidth,
          height: sparklineHeight,
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              quote.priceLabel,
              style: context.typography.cardTitleSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs + 1,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: trend,
                borderRadius: AppRadius.pillRadius,
              ),
              child: Text(
                quote.changeLabel,
                style: context.typography.overline.copyWith(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Attribution and session state; both are part of the data's honesty.
class _BoardFooter extends StatelessWidget {
  const _BoardFooter({required this.board});

  final IndexBoard board;

  @override
  Widget build(BuildContext context) {
    final String status = board.isOpen ? 'Market is open' : 'Market is closed';
    final TextStyle faint = context.typography.caption.copyWith(
      color: context.colors.onSurfaceFaint,
      fontSize: 10,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                'Data via ${MarketDataNotice.friendlySource(board.sourceLabel)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: faint,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: faint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text('Not investment advice. Quotes may be delayed.', style: faint),
      ],
    );
  }
}

/// "Updated 12 minutes ago" helper for the Stocks page header.
extension IndexBoardAge on IndexBoard {
  String get updatedLabel => 'Updated ${updatedAt.relativeLabel}';
}
