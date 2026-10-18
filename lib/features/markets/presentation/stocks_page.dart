import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/models/index_quote.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/category_pills.dart';
import '../../../core/widgets/state_views.dart';
import 'widgets/sparkline.dart';
import 'widgets/stocks_card.dart';

/// Full Stocks surface behind the For You card.
///
/// The reference opens a board with filter tabs (Index / Trending / Most active /
/// Top gain) and one row per index; this is that page, with the same rows as the
/// card plus the attribution and session line.
class StocksPage extends ConsumerStatefulWidget {
  const StocksPage({super.key});

  @override
  ConsumerState<StocksPage> createState() => _StocksPageState();
}

/// Board filters. "Most active" is ordered by points moved, because the quote
/// feed exposes no volume; the label stays honest by ordering on what it has.
enum StocksFilter { overview, trending, mostActive, topGain }

class _StocksPageState extends ConsumerState<StocksPage> {
  StocksFilter _filter = StocksFilter.overview;

  List<IndexQuote> _rows(IndexBoard board) {
    final List<IndexQuote> rows = List<IndexQuote>.of(board.quotes);
    switch (_filter) {
      case StocksFilter.overview:
        return rows;
      case StocksFilter.trending:
        rows.sort(
          (IndexQuote a, IndexQuote b) =>
              b.changePercent.abs().compareTo(a.changePercent.abs()),
        );
        return rows;
      case StocksFilter.mostActive:
        rows.sort(
          (IndexQuote a, IndexQuote b) => (b.price * b.changePercent.abs())
              .compareTo(a.price * a.changePercent.abs()),
        );
        return rows;
      case StocksFilter.topGain:
        rows.sort(
          (IndexQuote a, IndexQuote b) =>
              b.changePercent.compareTo(a.changePercent),
        );
        return rows;
    }
  }

  @override
  Widget build(BuildContext context) {
    final IndexBoard? board = ref.watch(indexBoardProvider).value;
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        leading: BackButton(color: context.colors.onSurface),
        title: const Text('Stocks'),
      ),
      body: board == null || board.isEmpty
          ? const EmptyStateView(
              title: 'No market data yet',
              message:
                  'The board fills in as soon as the quotes service answers.',
              icon: Icons.show_chart,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: <Widget>[
                _FilterStrip(
                  selected: _filter,
                  onSelected: (StocksFilter filter) =>
                      setState(() => _filter = filter),
                ),
                const SizedBox(height: AppSpacing.md),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: AppRadius.cardRadius,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (final IndexQuote quote in _rows(
                          board,
                        )) ...<Widget>[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: IndexQuoteRow(
                              quote: quote,
                              sparklineWidth: 76,
                              sparklineHeight: 26,
                            ),
                          ),
                          Divider(height: 1, color: context.colors.divider),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Powered by ${board.sourceLabel}',
                        style: context.typography.caption.copyWith(
                          color: context.colors.onSurfaceFaint,
                        ),
                      ),
                    ),
                    Text(
                      board.isOpen ? 'Market is open' : 'Market is closed',
                      style: context.typography.caption.copyWith(
                        color: context.colors.onSurfaceFaint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  board.updatedLabel,
                  style: context.typography.caption.copyWith(
                    color: context.colors.onSurfaceFaint,
                  ),
                ),
              ],
            ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({required this.selected, required this.onSelected});

  final StocksFilter selected;
  final ValueChanged<StocksFilter> onSelected;

  static const Map<StocksFilter, String> _labels = <StocksFilter, String>{
    StocksFilter.overview: 'Index',
    StocksFilter.trending: 'Trending',
    StocksFilter.mostActive: 'Most active',
    StocksFilter.topGain: 'Top gain',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final MapEntry<StocksFilter, String> entry
              in _labels.entries) ...<Widget>[
            CategoryPill(
              label: entry.value,
              selected: entry.key == selected,
              onTap: () => onSelected(entry.key),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

/// Sparkline re-export so tests and callers do not need two imports.
typedef StockSparkline = Sparkline;
