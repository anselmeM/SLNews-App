import 'package:flutter/material.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/theme/app_typography.dart';

/// "Morning/Afternoon/Evening briefing" band.
///
/// Modelled on Samsung News' briefing: a full-bleed gradient section with a
/// large white heading and three bullet headlines — no card chrome, no numbers,
/// so it reads as an editorial front page rather than another feed card.
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
    final Color deep = context.colors.accentGradientEnd;
    final Color lift = context.colors.accentGradientStart;

    return Semantics(
      header: true,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color.lerp(deep, Colors.black, 0.28)!,
              deep,
              Color.lerp(lift, deep, 0.35)!,
            ],
            stops: const <double>[0, 0.55, 1],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: context.typography.screenTitle.copyWith(
                color: ink,
                fontSize: 32,
                height: 1.08,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 22),
            for (int i = 0; i < articles.length; i++) ...<Widget>[
              _BriefingBullet(
                article: articles[i],
                ink: ink,
                onTap: onOpen == null ? null : () => onOpen!(articles[i]),
              ),
              if (i != articles.length - 1) const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _BriefingBullet extends StatelessWidget {
  const _BriefingBullet({required this.article, required this.ink, this.onTap});

  final Article article;
  final Color ink;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ink.withValues(alpha: 0.9),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                article.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.typography.cardTitle.copyWith(
                  color: ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  letterSpacing: -0.2,
                ),
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
