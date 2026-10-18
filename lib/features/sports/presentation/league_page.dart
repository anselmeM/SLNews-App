import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/article.dart';
import '../../../core/domain/models/sports_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/article_tile.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/sports_links.dart';
import 'widgets/sports_fixture_row.dart';
import 'widgets/standings_table.dart';

/// A league surface (`/sports/league/:id`): table, fixtures and stories.
///
/// The reference groups sports content by competition and gives each group a
/// "More … stories" doorway; this is that destination, also reachable by tapping
/// a league chip on the Sports tab.
class LeaguePage extends ConsumerWidget {
  const LeaguePage({super.key, required this.leagueId, this.leagueLabel});

  final String leagueId;

  /// Real label passed by the caller; deep links fall back to the id.
  final String? leagueLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String label = leagueLabel?.trim().isNotEmpty == true
        ? leagueLabel!.trim()
        : SportsLinks.leagueLabelForId(leagueId);
    final AsyncValue<List<TeamStanding>> standings = ref.watch(
      standingsProvider(leagueId),
    );
    final AsyncValue<ScoreboardSnapshot> scoreboard = ref.watch(
      scoreboardProvider,
    );
    final AsyncValue<List<Article>> stories = ref.watch(
      categoryFeedProvider('sports'),
    );

    return Scaffold(
      backgroundColor: context.colors.canvas,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            backgroundColor: context.colors.canvas,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () => context.pop(),
            ),
            title: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.groupTitle,
            ),
          ),
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Standings', compact: true),
          ),
          _standingsSliver(context, ref, standings, label),
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Fixtures & results', compact: true),
          ),
          _fixturesSliver(context, ref, scoreboard, label),
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Latest stories', compact: true),
          ),
          _storiesSliver(context, ref, stories),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
        ],
      ),
    );
  }

  Widget _standingsSliver(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<TeamStanding>> standings,
    String label,
  ) {
    return standings.when(
      data: (List<TeamStanding> rows) {
        if (rows.isEmpty) {
          return _notice(context, 'No standings published for $label yet.');
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: StandingsTable(
              rows: rows,
              onTeamTap: (TeamStanding row) => context.push(
                AppRoutes.teamFor(row.team.id),
                extra: row.team.name,
              ),
            ),
          ),
        );
      },
      loading: () => _notice(context, 'Loading standings…'),
      error: (Object error, StackTrace stack) => _notice(
        context,
        'Standings are unavailable right now.',
        onRetry: () => ref.invalidate(standingsProvider),
      ),
    );
  }

  Widget _fixturesSliver(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<ScoreboardSnapshot> scoreboard,
    String label,
  ) {
    return scoreboard.when(
      data: (ScoreboardSnapshot snapshot) {
        final List<GameScore> games = snapshot.games
            .where(
              (GameScore game) =>
                  game.leagueLabel.trim().toLowerCase() ==
                      label.toLowerCase() ||
                  SportsLinks.leagueIdForLabel(game.leagueLabel) ==
                      SportsLinks.leagueIdForLabel(label),
            )
            .toList(growable: false);
        if (games.isEmpty) {
          return _notice(context, 'No fixtures listed for $label right now.');
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverList.separated(
            itemCount: games.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) => SportsFixtureRow(
              game: games[index],
              onTap: () => context.push(
                AppRoutes.teamFor(games[index].home.id),
                extra: games[index].home.name,
              ),
            ),
          ),
        );
      },
      loading: () => _notice(context, 'Loading fixtures…'),
      error: (Object error, StackTrace stack) => _notice(
        context,
        'Fixtures are unavailable right now.',
        onRetry: () => ref.invalidate(scoreboardProvider),
      ),
    );
  }

  Widget _storiesSliver(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Article>> stories,
  ) {
    return stories.when(
      data: (List<Article> articles) {
        if (articles.isEmpty) {
          return _notice(context, 'No stories yet.');
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverList.separated(
            itemCount: articles.length.clamp(0, 8),
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) => ArticleTile(
              article: articles[index],
              onTap: () =>
                  context.push(AppRoutes.articleFor(articles[index].id)),
            ),
          ),
        );
      },
      loading: () => _notice(context, 'Loading stories…'),
      error: (Object error, StackTrace stack) => _notice(
        context,
        'Stories are unavailable right now.',
        onRetry: () => ref.invalidate(categoryFeedProvider),
      ),
    );
  }

  Widget _notice(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: AppRadius.cardRadius,
          ),
          child: Row(
            children: <Widget>[
              Expanded(child: Text(message, style: context.typography.caption)),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared empty state for sports surfaces that cannot resolve a team yet.
Widget sportsUnavailable(BuildContext context, String message) {
  return SafeArea(
    child: EmptyStateView(title: 'Nothing here yet', message: message),
  );
}
