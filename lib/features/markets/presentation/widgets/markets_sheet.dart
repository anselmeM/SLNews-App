import 'package:flutter/material.dart';

import '../../../../core/domain/models/market_snapshot.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/time_ago.dart';

/// Full currency board, opened from the interactive Markets card.
///
/// The reference app opens a finance module in a sheet; this keeps that shape
/// with our own data: the tracked pairs against the dollar, the reverse rate for
/// the majors, the timestamp and the attribution. No third-party page is framed.
Future<void> showMarketsSheet(
  BuildContext context, {
  required MarketSnapshot? snapshot,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (BuildContext sheetContext) {
      final MarketSnapshot board = snapshot ?? MarketSnapshot.empty;
      final List<MarketRate> rows = board.board;

      return SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.62,
          maxChildSize: 0.9,
          builder: (BuildContext context, ScrollController controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'Markets',
                      style: sheetContext.typography.sectionTitle,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                Text(
                  board.isEmpty
                      ? 'Rates are unavailable offline. They return with a '
                            'connection.'
                      : '1 ${board.base} buys · updated '
                            '${TimeAgo.format(board.updatedAt)}',
                  style: sheetContext.typography.caption.copyWith(
                    color: sheetContext.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final MarketRate rate in rows) ...<Widget>[
                  _RateRow(rate: rate, board: board),
                  Divider(height: 1, color: sheetContext.colors.divider),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Indicative wholesale rates from ${board.source}. '
                  'They are not an offer to trade and lag the market.',
                  style: sheetContext.typography.caption.copyWith(
                    color: sheetContext.colors.onSurfaceFaint,
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.rate, required this.board});

  final MarketRate rate;
  final MarketSnapshot board;

  @override
  Widget build(BuildContext context) {
    final double? reverse = board.crossInBase(rate.info.code);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(rate.info.name, style: context.typography.body),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  reverse == null
                      ? rate.info.code
                      : '1 ${rate.info.code} = '
                            '${formatRate(reverse, decimals: 2)} ${board.base}',
                  style: context.typography.caption.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            rate.formatted,
            style: context.typography.cardTitleSmall.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
