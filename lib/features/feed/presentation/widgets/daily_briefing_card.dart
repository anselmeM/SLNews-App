import 'package:flutter/material.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// "Morning/Afternoon/Evening briefing" digest.
///
/// Deliberately the loudest card on the For You surface: an inverted panel with
/// a soft accent glow, a time-of-day headline, and numbered story rows with room
/// to breathe. Everything is token-driven, so it keeps working in dark mode.
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

    final Color ink = context.colors.onSurfaceInverse;
    final String updated = _updatedLabel(articles);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: ink.withValues(alpha: 0.10)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: context.colors.surfaceInverse),
              ),
            ),
            // Two soft accent orbs: depth without a background image.
            // Gradient hairline across the top edge.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      context.colors.accentGradientStart,
                      context.colors.accentGradientEnd,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -70,
              right: -50,
              child: _Glow(
                color: context.colors.accentGradientStart,
                size: 210,
              ),
            ),
            Positioned(
              bottom: -90,
              left: -60,
              child: _Glow(color: context.colors.accentGradientEnd, size: 190),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: ink.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.auto_awesome, size: 13, color: ink),
                            const SizedBox(width: 6),
                            Text(
                              'DAILY BRIEFING',
                              style: context.typography.overline.copyWith(
                                color: ink,
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (updated.isNotEmpty)
                        Text(
                          updated,
                          style: context.typography.meta.copyWith(
                            color: ink.withValues(alpha: 0.55),
                            letterSpacing: 0.8,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    title,
                    style: context.typography.heroTitle.copyWith(
                      color: ink,
                      height: 1.05,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The three stories that matter right now, in two minutes.',
                    style: context.typography.body.copyWith(
                      color: ink.withValues(alpha: 0.62),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(height: 1, color: ink.withValues(alpha: 0.10)),
                  for (int i = 0; i < articles.length; i++) ...<Widget>[
                    _BriefingRow(
                      index: i + 1,
                      article: articles[i],
                      ink: ink,
                      onTap: onOpen == null ? null : () => onOpen!(articles[i]),
                    ),
                    if (i != articles.length - 1)
                      Divider(height: 1, color: ink.withValues(alpha: 0.08)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "UPDATED 18:42" from the newest story, kept free of `DateTime.now()` so
  /// golden tests don't change with the wall clock.
  String _updatedLabel(List<Article> stories) {
    DateTime? newest;
    for (final Article article in stories) {
      if (newest == null || article.publishedAt.isAfter(newest)) {
        newest = article.publishedAt;
      }
    }
    if (newest == null) return '';
    final DateTime local = newest.toLocal();
    final String hh = local.hour.toString().padLeft(2, '0');
    final String mm = local.minute.toString().padLeft(2, '0');
    return 'UPDATED $hh:$mm';
  }
}

class _BriefingRow extends StatelessWidget {
  const _BriefingRow({
    required this.index,
    required this.article,
    required this.ink,
    this.onTap,
  });

  final int index;
  final Article article;
  final Color ink;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ink.withValues(alpha: 0.08),
                border: Border.all(color: ink.withValues(alpha: 0.16)),
              ),
              child: Text(
                index.toString().padLeft(2, '0'),
                style: context.typography.meta.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.cardTitle.copyWith(
                      color: ink,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.publisher.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.overline.copyWith(
                      color: ink.withValues(alpha: 0.50),
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Icon(
                Icons.arrow_outward_rounded,
                size: 17,
                color: ink.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft radial accent, used to give the panel depth.
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: 0.38),
              color.withValues(alpha: 0),
            ],
          ),
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
