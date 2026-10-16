import 'package:flutter/material.dart';

import '../../../../core/domain/models/sports_models.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/time_ago.dart';
import 'team_crest.dart';

/// One fixture inside the live scoreboard strip.
///
/// Layout mirrors the reference scoreboard: a small grey league label, a date
/// row whose right edge carries the status (a red `LIVE`/period label for games
/// in play, `FINAL`/kick-off time otherwise), then one row per side with the
/// crest, the three-letter code and the score. The losing side is muted so the
/// winning score reads first.
class ScoreCard extends StatelessWidget {
  const ScoreCard({super.key, required this.game});

  final GameScore game;

  @override
  Widget build(BuildContext context) {
    final bool isLive = game.status == GameStatus.live;
    final DateTime? startsAt = game.startsAt;
    final Color statusColour = isLive
        ? context.colors.live
        : context.colors.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            game.leagueLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typography.overline,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  startsAt?.shortDateLabel ?? 'Today',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.meta,
                ),
              ),
              if (isLive) ...<Widget>[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: context.colors.live,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Text(
                  game.statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.overline.copyWith(color: statusColour),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _teamRow(
            context,
            team: game.home,
            score: game.homeScore,
            opponentScore: game.awayScore,
          ),
          const SizedBox(height: AppSpacing.sm),
          _teamRow(
            context,
            team: game.away,
            score: game.awayScore,
            opponentScore: game.homeScore,
          ),
        ],
      ),
    );
  }

  /// Crest + code + score for one side; the lower score is muted.
  Widget _teamRow(
    BuildContext context, {
    required Team team,
    required int? score,
    required int? opponentScore,
  }) {
    final bool muted = score != null && opponentScore != null && score < opponentScore;
    final TextStyle style = context.typography.score.copyWith(
      color: muted ? context.colors.onSurfaceVariant : context.colors.onSurface,
    );
    return Row(
      children: <Widget>[
        TeamCrest(name: team.name, logoUrl: team.logoUrl, colourHex: team.colourHex),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            team.code,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(score?.toString() ?? '–', style: style),
      ],
    );
  }
}
