import 'package:flutter/material.dart';

import '../../../../core/domain/models/market_snapshot.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'paged_carousel.dart';
import '../../../../core/widgets/pressable_ink_well.dart';

/// "Stocks" section of the For You feed: the day's quotes, one card per pair.
///
/// The deployed scraper exposes exchange rates rather than equities, so the
/// cards show what the app can actually source - one unit of the base currency in
/// the leone, pound, euro and regional currencies - with the same swipeable,
/// snap-to-card behaviour as the lead-stories carousel.
class StocksCarousel extends StatelessWidget {
  const StocksCarousel({
    super.key,
    required this.rates,
    this.onOpen,
    this.height = 148,
  });

  final List<MarketRate> rates;

  /// Opens the full board for the tapped quote.
  final ValueChanged<MarketRate>? onOpen;

  final double height;

  @override
  Widget build(BuildContext context) {
    if (rates.isEmpty) return const SizedBox.shrink();

    return PagedCarousel(
      height: height,
      itemCount: rates.length,
      itemBuilder: (BuildContext context, int index) {
        final MarketRate rate = rates[index];
        return _QuoteCard(
          rate: rate,
          onTap: onOpen == null ? null : () => onOpen!(rate),
        );
      },
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.rate, this.onTap});

  final MarketRate rate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '${rate.info.name}, ${rate.formatted} per US dollar',
      child: PressableInkWell(
        onTap: onTap,
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
                    Expanded(
                      child: Text(
                        rate.info.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.caption.copyWith(
                          color: context.colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
                        rate.info.code,
                        style: context.typography.overline.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  rate.formatted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.sectionTitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'per 1 US dollar',
                  style: context.typography.caption.copyWith(
                    color: context.colors.onSurfaceFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
