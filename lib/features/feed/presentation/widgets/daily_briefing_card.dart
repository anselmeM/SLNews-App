import 'package:flutter/material.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// "Evening briefing" digest, as the reference puts above the carousel: a titled
/// card with three tappable headline bullets that open the stories.
class DailyBriefingCard extends StatelessWidget {
  const DailyBriefingCard({
    super.key,
    required this.title,
    required this.articles,
    this.onOpen,
  });

  final String title;
  final List<Article> articles;
  final ValueChanged<Article>? onOpen;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceInverse,
        borderRadius: AppRadius.cardRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.wb_twilight,
                  size: 18,
                  color: context.colors.onSurfaceInverse,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: context.typography.groupTitle.copyWith(
                      color: context.colors.onSurfaceInverse,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final Article article in articles)
            InkWell(
              onTap: onOpen == null ? null : () => onOpen!(article),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        article.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.body.copyWith(
                          color: context.colors.onSurfaceInverse,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: context.colors.onSurfaceFaint,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }
}

/// Briefing title for the current time of day.
String briefingTitleFor(DateTime now) {
  if (now.hour < 12) return 'Morning briefing';
  if (now.hour < 17) return 'Afternoon briefing';
  return 'Evening briefing';
}
