import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/personalization_profile.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/article_grid_tile.dart';
import '../../../../core/widgets/section_header.dart';

/// Unfinished stories with a visible reading-progress bar.
///
/// Only stories the reader actually started and left partly read appear here.
/// The position is device-local and never synchronized.
class ContinueReadingRail extends ConsumerWidget {
  const ContinueReadingRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<ContinueReadingEntry> entries =
        ref.watch(continueReadingProvider).value ??
        const <ContinueReadingEntry>[];
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(left: AppSpacing.lg, top: AppSpacing.md),
          child: SectionHeader(
            title: 'Continue reading',
            subtitle: 'Pick up where you left off',
          ),
        ),
        SizedBox(
          height: 238,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: entries.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final ContinueReadingEntry entry = entries[index];
              final int percent = (entry.progress * 100).round();
              return SizedBox(
                width: 190,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: ArticleGridTile(
                        article: entry.article,
                        maxTitleLines: 2,
                        onTap: () => context.push(
                          AppRoutes.articleFor(entry.article.id),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: entry.progress.clamp(0.0, 1.0).toDouble(),
                        minHeight: 4,
                        backgroundColor: context.colors.surfaceMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '$percent% read',
                      style: context.typography.caption.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
