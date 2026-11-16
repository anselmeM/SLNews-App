import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/domain/models/article.dart';
import '../../../core/domain/models/sports_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/article_tile.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/sports_links.dart';
import '../domain/league_stories.dart';
import '../domain/sports_league_catalog.dart';
import '../../../core/data/sources/league_news_source.dart';
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
    // The European competitions are one Sports section; this page is the way
    // into the four leagues it covers, so they are listed instead of a table
    // the merged pseudo-league cannot have.
    final List<SportsLeague> members = mergedLeagueMembers(leagueId);
    final Set<String> fixtureLeagueIds = <String>{
      SportsLinks.leagueIdForLabel(label),
      for (final SportsLeague member in members) member.id,
    };
    final AsyncValue<List<TeamStanding>> standings = ref.watch(
      standingsProvider(leagueId),
    );
    final AsyncValue<ScoreboardSnapshot> scoreboard = ref.watch(
      scoreboardProvider,
    );
    final AsyncValue<List<Article>> allStories = ref.watch(
      categoryFeedProvider('sports'),
    );
    final List<GameScore> leagueGames =
        scoreboard.asData?.value.games
            .where(
              (GameScore game) => fixtureLeagueIds.contains(
                SportsLinks.leagueIdForLabel(game.leagueLabel),
              ),
            )
            .toList(growable: false) ??
        const <GameScore>[];
    final AsyncValue<List<Article>> leagueFeed = ref.watch(
      leagueNewsProvider('league:${SportsLinks.leagueIdForLabel(label)}'),
    );
    final AsyncValue<List<Article>> stories =
        leagueFeed.asData?.value.isNotEmpty == true
        ? leagueFeed
        : allStories.whenData(
            (List<Article> articles) => LeagueStories.forLeague(
              label,
              articles,
              games: leagueGames,
              limit: 6,
            ),
          );

    return Theme(
      data: AppTheme.dark(),
      // The page paints itself dark whatever the reader's theme is, so every
      // colour must be read from a context *below* this Theme. Building the
      // body in a Builder is what guarantees that; using the outer context
      // mixed dark section headers with light surfaces and made them
      // illegible in light mode.
      child: Builder(
        builder: (BuildContext themed) => Scaffold(
          backgroundColor: themed.colors.canvas,
          body: CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                backgroundColor: themed.colors.canvas,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                  onPressed: () => themed.pop(),
                ),
                title: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: themed.typography.groupTitle,
                ),
              ),
              if (members.isEmpty) ...<Widget>[
                const SliverToBoxAdapter(
                  child: SectionHeader(title: 'Standings', compact: true),
                ),
                _standingsSliver(themed, ref, standings, label),
              ] else ...<Widget>[
                const SliverToBoxAdapter(
                  child: SectionHeader(title: 'Leagues', compact: true),
                ),
                _membersSliver(themed, members),
              ],
              const SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Fixtures & results',
                  compact: true,
                ),
              ),
              _fixturesSliver(themed, ref, scoreboard, label, fixtureLeagueIds),
              const SliverToBoxAdapter(
                child: SectionHeader(title: 'Latest stories', compact: true),
              ),
              _storiesSliver(themed, ref, stories),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxxl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The competitions a merged section covers, each opening its own page.
  Widget _membersSliver(BuildContext context, List<SportsLeague> members) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      sliver: SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: AppRadius.cardRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              for (int index = 0; index < members.length; index++) ...<Widget>[
                if (index > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: context.colors.divider,
                  ),
                Semantics(
                  button: true,
                  label: 'Open ${members[index].label}',
                  child: InkWell(
                    onTap: () => context.push(
                      AppRoutes.leagueFor(members[index].id),
                      extra: members[index].label,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              members[index].label,
                              style: context.typography.groupTitle,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 22,
                            color: context.colors.onSurfaceFaint,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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
    Set<String> leagueIds,
  ) {
    return scoreboard.when(
      data: (ScoreboardSnapshot snapshot) {
        final List<GameScore> games = snapshot.games
            .where(
              (GameScore game) => leagueIds.contains(
                SportsLinks.leagueIdForLabel(game.leagueLabel),
              ),
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
              onTap: () {
                final Article article = articles[index];
                final String? external = article.sourceUrl;
                if (isExternalSportsArticle(article) && external != null) {
                  unawaited(
                    launchUrl(
                      Uri.parse(external),
                      mode: LaunchMode.externalApplication,
                    ),
                  );
                  return;
                }
                context.push(AppRoutes.articleFor(article.id));
              },
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
