import 'package:flutter/material.dart';

import '../../../../core/domain/models/sports_models.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/time_ago.dart';
import 'paged_carousel.dart';

/// "Sports" section of the For You feed: live and upcoming fixtures, one card
/// per game, swipeable with the same snap-to-card behaviour as the lead stories.
class SportsCarousel extends StatelessWidget {
  const SportsCarousel({
    super.key,
    required this.games,
    this.onOpen,
    this.height = 156,
  });

  final List<GameScore> games;

  /// Opens the full sports surface for the tapped game.
  final ValueChanged<GameScore>? onOpen;

  final double height;

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) return const SizedBox.shrink();

    return PagedCarousel(
      height: height,
      itemCount: games.length,
      itemBuilder: (BuildContext context, int index) {
        final GameScore game = games[index];
        return _FixtureCard(
          game: game,
          onTap: onOpen == null ? null : () => onOpen!(game),
        );
      },
    );
  }
}

/// Status text a reader understands: "LIVE", "FT", "Postponed" or when it starts.
String fixtureStatusLabel(GameScore game) {
  switch (game.status) {
    case GameStatus.live:
      return game.periodLabel?.trim().isNotEmpty == true
          ? game.periodLabel!.trim().toUpperCase()
          : 'LIVE';
    case GameStatus.finalScore:
      return 'FT';
    case GameStatus.postponed:
      return 'POSTPONED';
    case GameStatus.scheduled:
      final DateTime? startsAt = game.startsAt;
      if (startsAt == null) return 'SCHEDULED';
      return startsAt.shortDateLabel.toUpperCase();
  }
}

/// Whether the fixture has a score worth printing.
bool fixtureHasScore(GameScore game) =>
    game.awayScore != null || game.homeScore != null;

class _FixtureCard extends StatelessWidget {
  const _FixtureCard({required this.game, this.onTap});

  final GameScore game;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasScore = fixtureHasScore(game);
    return Semantics(
      button: onTap != null,
      label:
          '${game.away.name} versus ${game.home.name}, ${fixtureStatusLabel(game)}',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: AppRadius.cardRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        game.leagueLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.caption.copyWith(
                          color: context.colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatusChip(
                      label: fixtureStatusLabel(game),
                      isLive: game.status == GameStatus.live,
                    ),
                  ],
                ),
                const Spacer(),
                _TeamLine(
                  team: game.away,
                  score: hasScore ? game.awayScore : null,
                ),
                const SizedBox(height: AppSpacing.xs),
                _TeamLine(
                  team: game.home,
                  score: hasScore ? game.homeScore : null,
                ),
                if (game.venue != null &&
                    game.venue!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    game.venue!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.caption.copyWith(
                      color: context.colors.onSurfaceFaint,
                    ),
                  ),
                ],
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
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.colors.surfaceMuted,
            shape: BoxShape.circle,
          ),
          child: Text(
            team.code,
            style: context.typography.overline.copyWith(
              color: context.colors.onSurface,
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
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (score != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$score',
            style: context.typography.cardTitleSmall.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
        color: isLive ? context.colors.live : context.colors.surfaceMuted,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        label,
        style: context.typography.overline.copyWith(
          color: isLive ? Colors.white : context.colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
