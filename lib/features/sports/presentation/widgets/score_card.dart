import 'package:flutter/material.dart';

import '../../../../core/domain/models/sports_models.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/time_ago.dart';
import 'team_crest.dart';

/// One fixture inside the live scoreboard strip.
///
/// The card intentionally uses the same surface, hairline outline and compact
/// typography as the rest of the reader instead of a separate scoreboard skin:
/// a quiet league overline, one date/status line, then two team rows. Winning
/// scores stay primary; losing and draw scores are muted.
class ScoreCard extends StatelessWidget {
  const ScoreCard({super.key, required this.game});

  final GameScore game;

  @override
  Widget build(BuildContext context) {
    final bool isLive = game.status == GameStatus.live;
    final DateTime? startsAt = game.startsAt;
    final Color statusColour = isLive
        ? context.colors.live
        : context.colors.onSurfaceFaint;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: context.colors.divider.withValues(alpha: 0.55),
          width: 0.75,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            game.leagueLabel.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typography.overline.copyWith(
              fontSize: 10,
              letterSpacing: 0.7,
              color: context.colors.onSurfaceFaint,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  startsAt?.shortDateLabel ?? 'Today',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.caption.copyWith(
                    color: context.colors.onSurfaceFaint,
                  ),
                ),
              ),
              if (isLive) ...<Widget>[
                Container(
                  width: 5,
                  height: 5,
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
                  style: context.typography.overline.copyWith(
                    fontSize: 10,
                    color: statusColour,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(
            height: 1,
            thickness: 0.5,
            color: context.colors.divider.withValues(alpha: 0.45),
          ),
          const SizedBox(height: AppSpacing.sm),
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
    final bool muted =
        score != null && opponentScore != null && score < opponentScore;
    final TextStyle teamStyle = context.typography.button.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: muted ? context.colors.onSurfaceFaint : context.colors.onSurface,
    );
    final TextStyle scoreStyle = context.typography.score.copyWith(
      fontSize: 18,
      color: muted ? context.colors.onSurfaceVariant : context.colors.onSurface,
    );
    return Row(
      children: <Widget>[
        TeamCrest(
          name: team.name,
          logoUrl: team.logoUrl,
          colourHex: team.colourHex,
          size: 24,
          monochrome: true,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            team.code.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: teamStyle,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 28,
          child: Text(
            score?.toString() ?? '–',
            textAlign: TextAlign.right,
            style: scoreStyle,
          ),
        ),
      ],
    );
  }
}
