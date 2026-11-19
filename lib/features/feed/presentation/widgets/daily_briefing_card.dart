import 'package:flutter/material.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/pressable_ink_well.dart';

/// "Morning/Afternoon/Evening briefing" card at the top of For You.
///
/// Styled like the rest of the feed — a surface card with the standard radius,
/// a tinted icon tile and numbered rows — instead of the old full-bleed gradient
/// band, which read as a different product bolted onto the feed.
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

    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceMuted,
                    borderRadius: AppRadius.pillRadius,
                  ),
                  child: Icon(
                    _iconFor(title),
                    size: 20,
                    color: context.colors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'DAILY BRIEFING',
                        style: context.typography.overline.copyWith(
                          color: context.colors.onSurfaceVariant,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: context.typography.groupTitle,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${articles.length} ${articles.length == 1 ? 'story' : 'stories'}',
                  style: context.typography.caption.copyWith(
                    color: context.colors.onSurfaceFaint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (int i = 0; i < articles.length; i++) ...<Widget>[
              _BriefingRow(
                index: i,
                article: articles[i],
                onTap: onOpen == null ? null : () => onOpen!(articles[i]),
              ),
              if (i != articles.length - 1)
                Divider(height: 1, color: context.colors.divider, indent: 30),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String title) {
    final String lower = title.toLowerCase();
    if (lower.contains('evening') || lower.contains('night')) {
      return Icons.nights_stay_outlined;
    }
    return Icons.wb_sunny_outlined;
  }
}

class _BriefingRow extends StatelessWidget {
  const _BriefingRow({required this.index, required this.article, this.onTap});

  final int index;
  final Article article;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableInkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 22,
              child: Text(
                '${index + 1}'.padLeft(2, '0'),
                style: context.typography.overline.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                article.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.typography.cardTitleSmall.copyWith(height: 1.35),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: context.colors.onSurfaceFaint,
              ),
            ),
          ],
        ),
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
