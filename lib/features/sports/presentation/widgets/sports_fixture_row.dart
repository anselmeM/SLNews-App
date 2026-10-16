import 'package:flutter/material.dart';

import '../../../../core/domain/models/sports_models.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/time_ago.dart';

/// Compact fixtures / results row used by the Sports tab.
///
/// Left column: the competition and the two sides; right column: the score (or
/// the kick-off / status label when the game has not been played). Tapping the
/// row is handled by the page, which currently raises a `SnackBar`.
class SportsFixtureRow extends StatelessWidget {
  const SportsFixtureRow({super.key, required this.game, this.onTap});

  final GameScore game;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isLive = game.status == GameStatus.live;
    final DateTime? startsAt = game.startsAt;
    final String primary = game.hasScores
        ? '${game.awayScore} – ${game.homeScore}'
        : game.statusLabel;
    final String secondary = game.hasScores
        ? game.statusLabel
        : (startsAt?.shortDateLabel ?? 'Date to be confirmed');

    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppSpacing.row,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
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
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${game.away.name} v ${game.home.name}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.cardTitleSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    primary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.score.copyWith(
                      color: isLive ? context.colors.live : context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.overline.copyWith(
                      color: isLive ? context.colors.live : context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
