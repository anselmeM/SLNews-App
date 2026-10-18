import 'package:flutter/material.dart';

import '../../../../core/domain/models/sports_models.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/time_ago.dart';
import '../../../../core/widgets/pressable_ink_well.dart';

/// The reference's sports scoreboard card: a colour-washed board for one fixture,
/// with the league, session state and both sides, credited underneath.
///
/// It is the For You summary of the Sports tab, so tapping it opens that tab
/// rather than a detail screen the app does not have yet.
class SportSpotlightCard extends StatelessWidget {
  const SportSpotlightCard({
    super.key,
    required this.game,
    this.onTap,
    this.updatedAt,
  });

  final GameScore game;
  final VoidCallback? onTap;

  /// When the snapshot behind the card was read, shown in the footer.
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    final bool isLive = game.status == GameStatus.live;
    final bool hasScore = game.awayScore != null || game.homeScore != null;
    final DateTime? readAt = updatedAt ?? game.startsAt;

    return Semantics(
      button: onTap != null,
      label: '${game.away.name} versus ${game.home.name}, ${game.statusLabel}',
      child: PressableInkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            // The reference tints each sport's board; purple for basketball,
            // which is what the recorded feed showed.
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF6A4C93), Color(0xFF8F6BB5)],
            ),
            borderRadius: AppRadius.cardRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        game.leagueLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.overline.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatusChip(label: game.statusLabel, isLive: isLive),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _TeamLine(
                  team: game.away,
                  score: hasScore ? game.awayScore : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                _TeamLine(
                  team: game.home,
                  score: hasScore ? game.homeScore : null,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Powered by SLNews Sports',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.caption.copyWith(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    if (readAt != null)
                      Text(
                        isLive ? 'Live now' : readAt.relativeLabel,
                        style: context.typography.caption.copyWith(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({required this.team, required this.score});

  final Team team;
  final int? score;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
          child: Text(
            team.code,
            style: context.typography.overline.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            team.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typography.cardTitleSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (score != null)
          Text(
            '$score',
            style: context.typography.cardTitle.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.isLive});

  final String label;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isLive ? const Color(0xFFD32F2F) : Colors.white24,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        label,
        style: context.typography.overline.copyWith(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
