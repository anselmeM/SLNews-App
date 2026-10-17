import 'package:flutter/material.dart';

import '../../../../core/domain/models/market_snapshot.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/time_ago.dart';

/// The "Markets" interactive card in the For You feed.
///
/// This is the surface the reader's *Interactive content* switch gates: with the
/// switch off the card is not built at all, which is what makes that setting
/// mean something. Rates come from the keyless currency board and are cached, so
/// the card keeps working offline — it says how old the numbers are either way.
class MarketRatesCard extends StatelessWidget {
  const MarketRatesCard({super.key, required this.snapshot, this.onOpen});

  final MarketSnapshot? snapshot;
  final VoidCallback? onOpen;

  /// The three pairs the card quotes: the leone first, then the majors.
  static const List<String> headlineCodes = <String>['SLE', 'GBP', 'EUR'];

  @override
  Widget build(BuildContext context) {
    final MarketSnapshot? board = snapshot;
    final bool hasRates = board != null && !board.isEmpty;
    final String freshness =
        hasRates && board.updatedAt.millisecondsSinceEpoch > 0
        ? 'updated ${TimeAgo.format(board.updatedAt)}'
        : 'rates unavailable offline';

    return Semantics(
      button: hasRates,
      label: 'Markets. $freshness.',
      child: InkWell(
        onTap: hasRates ? onOpen : null,
        borderRadius: AppRadius.cardRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: AppRadius.cardRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text('Markets', style: context.typography.groupTitle),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceMuted,
                        borderRadius: AppRadius.pillRadius,
                      ),
                      child: Text(
                        'Interactive',
                        style: context.typography.overline.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (hasRates)
                      Icon(
                        Icons.chevron_right,
                        size: 22,
                        color: context.colors.onSurfaceVariant,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  hasRates ? '1 USD buys · $freshness' : freshness,
                  style: context.typography.caption.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                if (hasRates) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      for (final String code in headlineCodes)
                        if (board.rateOf(code) != null)
                          Expanded(
                            child: _Rate(
                              label: _label(code),
                              value: board.rateOf(code)!,
                              decimals: code == 'SLE' ? 2 : 4,
                            ),
                          ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _label(String code) => switch (code) {
    'SLE' => 'Leone (SLE)',
    'SLL' => 'Leone (SLL)',
    'GBP' => 'Pound',
    'EUR' => 'Euro',
    'NGN' => 'Naira',
    'GHS' => 'Cedi',
    _ => code,
  };
}

class _Rate extends StatelessWidget {
  const _Rate({
    required this.label,
    required this.value,
    required this.decimals,
  });

  final String label;
  final double value;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.typography.caption.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          formatRate(value, decimals: decimals),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.typography.cardTitleSmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
