import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/article.dart';
import '../../../core/domain/models/follow_models.dart';
import '../../../core/domain/models/sports_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/article_tile.dart';
import '../../../core/widgets/follow_chip.dart';
import '../../../core/widgets/section_header.dart';
import '../domain/sports_links.dart';
import 'widgets/sports_fixture_row.dart';
import 'widgets/team_crest.dart';

/// A team surface (`/sports/team/:id`): follow control, fixtures and stories.
///
/// Reached from the followed-teams row, the standings table and fixtures. The
/// name comes in as route extra when a row pushes it; a deep link falls back to
/// a title-cased id.
class TeamPage extends ConsumerWidget {
  const TeamPage({super.key, required this.teamId, this.teamName});

  final String teamId;
  final String? teamName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String name = teamName?.trim().isNotEmpty == true
        ? teamName!.trim()
        : SportsLinks.titleFromId(teamId);
    final FollowTarget target = FollowTarget(
      id: teamId,
      kind: FollowKind.team,
      label: name,
    );
    final bool isFollowing = ref
        .watch(followingControllerProvider)
        .isFollowed(target.id);
    final AsyncValue<List<GameScore>> fixtures = ref.watch(
      teamGamesProvider(teamId),
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
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.groupTitle,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  TeamCrest(name: name, size: 56),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(name, style: context.typography.sectionTitle),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Sports',
                          style: context.typography.caption.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FollowChip(
                    isFollowing: isFollowing,
                    dense: true,
                    onPressed: () => ref
                        .read(followingControllerProvider.notifier)
                        .toggle(target),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Fixtures & results', compact: true),
          ),
          _fixturesSliver(context, ref, fixtures),
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Latest stories', compact: true),
          ),
          _storiesSliver(context, ref, stories, name),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
        ],
      ),
    );
  }

  Widget _fixturesSliver(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<GameScore>> fixtures,
  ) {
    return fixtures.when(
      data: (List<GameScore> games) {
        if (games.isEmpty) {
          return _notice(context, 'No fixtures scheduled right now.');
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverList.separated(
            itemCount: games.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) => SportsFixtureRow(
              game: games[index],
              onTap: () => context.push(
                AppRoutes.leagueFor(
                  SportsLinks.leagueIdForLabel(games[index].leagueLabel),
                ),
                extra: games[index].leagueLabel,
              ),
            ),
          ),
        );
      },
      loading: () => _notice(context, 'Loading fixtures…'),
      error: (Object error, StackTrace stack) => _notice(
        context,
        'Fixtures are unavailable right now.',
        onRetry: () => ref.invalidate(teamGamesProvider(teamId)),
      ),
    );
  }

  Widget _storiesSliver(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Article>> stories,
    String name,
  ) {
    return stories.when(
      data: (List<Article> articles) {
        // Best-effort relevance: stories that mention the team by name first,
        // then the latest sports stories so the page is never empty.
        final List<Article> mentioning = articles
            .where(
              (Article article) =>
                  article.title.toLowerCase().contains(name.toLowerCase()) ||
                  article.summary.toLowerCase().contains(name.toLowerCase()),
            )
            .toList(growable: false);
        final List<Article> visible =
            (mentioning.isNotEmpty ? mentioning : articles)
                .take(6)
                .toList(growable: false);
        if (visible.isEmpty) {
          return _notice(context, 'No stories yet.');
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverList.separated(
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) => ArticleTile(
              article: visible[index],
              onTap: () =>
                  context.push(AppRoutes.articleFor(visible[index].id)),
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
