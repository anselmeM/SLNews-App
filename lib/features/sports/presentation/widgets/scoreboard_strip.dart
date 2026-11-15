import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/domain/models/sports_models.dart';
import '../../../../core/routing/app_routes.dart';
import '../../domain/sports_links.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/time_ago.dart';
import '../../../../core/widgets/skeleton.dart';
import 'score_card.dart';

/// Live scoreboard strip pinned at the top of the Sports tab.
///
/// Owns the three `AsyncValue` states of `scoreboardProvider` locally so a
/// failing scores feed degrades to a compact inline notice instead of blanking
/// the whole tab: the Following row, the news stream and the fixture list below
/// keep rendering. The strip scrolls horizontally with a 62% card width so the
/// next fixture peeks in, matching the reference paging.
class ScoreboardStrip extends ConsumerWidget {
  const ScoreboardStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ScoreboardSnapshot> scoreboard = ref.watch(
      scoreboardProvider,
    );

    return scoreboard.when(
      data: (ScoreboardSnapshot snapshot) => snapshot.games.isEmpty
          ? _notice(context, 'No live scores right now.')
          : _loaded(context, ref, snapshot),
      loading: () => const _StripSkeleton(),
      error: (Object error, StackTrace stack) => _notice(
        context,
        'Scores are unavailable right now.',
        onRetry: () => ref.invalidate(scoreboardProvider),
      ),
    );
  }

  /// A compact “Scores” header over the horizontal card rail.
  Widget _loaded(
    BuildContext context,
    WidgetRef ref,
    ScoreboardSnapshot snapshot,
  ) {
    final double cardWidth = (MediaQuery.sizeOf(context).width * 0.46).clamp(
      160.0,
      220.0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.xs,
            0,
          ),
          child: Row(
            children: <Widget>[
              Text(
                'Scores',
                style: context.typography.overline.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  '${_providerName(snapshot.providerLabel)} · '
                  '${snapshot.updatedAt.clockLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.caption.copyWith(
                    color: context.colors.onSurfaceFaint,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => ref.invalidate(scoreboardProvider),
                tooltip: 'Refresh scores',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.refresh,
                  size: 17,
                  color: context.colors.onSurfaceFaint,
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final GameScore game in snapshot.games)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: SizedBox(
                    width: cardWidth,
                    child: Semantics(
                      button: true,
                      label:
                          '${game.leagueLabel}: ${game.away.code} at ${game.home.code}',
                      child: GestureDetector(
                        onTap: () => context.push(
                          AppRoutes.leagueFor(
                            SportsLinks.leagueIdForLabel(game.leagueLabel),
                          ),
                          extra: game.leagueLabel,
                        ),
                        child: ScoreCard(game: game),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _providerName(String raw) {
    return switch (raw.toLowerCase()) {
      'thesportsdb' => 'TheSportsDB',
      'yahoo' => 'Yahoo Sports',
      _ => raw,
    };
  }

  /// Compact inline message; the rest of the screen must still render.
  Widget _notice(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 0),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.cardRadius,
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.scoreboard_outlined,
              size: 18,
              color: context.colors.onSurfaceFaint,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.typography.caption,
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Two placeholder cards mirroring the loaded strip geometry.
class _StripSkeleton extends StatelessWidget {
  const _StripSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: SkeletonBox(height: 132, borderRadius: AppRadius.cardRadius),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: SkeletonBox(height: 132, borderRadius: AppRadius.cardRadius),
          ),
        ],
      ),
    );
  }
}
