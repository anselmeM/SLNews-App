import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/ad_unit.dart';
import '../../../core/domain/models/article.dart';
import '../../../core/domain/models/follow_models.dart';
import '../../../core/domain/models/sports_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ad_card.dart';
import '../../../core/widgets/article_tile.dart';
import '../../../core/widgets/overflow_menu_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/sl_page_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import 'viewmodels/sports_view_model.dart';
import 'widgets/followed_teams_row.dart';
import 'widgets/scoreboard_strip.dart';
import 'widgets/sports_fixture_row.dart';

/// Tab 3 — Sports.
///
/// A single scroll view made of four independent streams:
///
/// 1. the live scoreboard strip ([ScoreboardStrip], owns its own states),
/// 2. the reader's followed teams / leagues ([FollowedTeamsRow]),
/// 3. one native inline ad from the `sports_stream` placement,
/// 4. the team's news stream and its fixtures & results.
///
/// Every stream degrades locally — an inline notice, a skeleton or nothing at
/// all — so a failing scores endpoint never blanks the tab. [ErrorStateView] is
/// reserved for the case where the screen genuinely has no data to show.
class SportsPage extends ConsumerWidget {
  const SportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ScoreboardSnapshot> scoreboard = ref.watch(scoreboardProvider);
    final FollowingSnapshot following = ref.watch(followingControllerProvider);
    final SportsViewModel viewModel = SportsViewModel.from(
      snapshot: scoreboard.asData?.value,
      following: following,
    );
    final AsyncValue<List<Article>> news = ref.watch(categoryFeedProvider('sports'));
    final AsyncValue<List<AdUnit>> ads = ref.watch(adUnitsProvider('sports_stream'));
    final Set<String> liked = ref.watch(likesControllerProvider);

    // Only the first followed team gets a news heading and a fixture list; the
    // provider family is not watched at all when no team is followed.
    final String? fixtureTeamId = viewModel.heroTeam?.id;
    final AsyncValue<List<GameScore>>? fixtures = fixtureTeamId == null
        ? null
        : ref.watch(teamGamesProvider(fixtureTeamId));

    final List<AdUnit> adUnits = ads.asData?.value ?? const <AdUnit>[];
    final AdUnit? ad = adUnits.isEmpty ? null : adUnits.first;

    final bool hasContent =
        viewModel.hasGames ||
        viewModel.hasFollowedSports ||
        (news.asData?.value.isNotEmpty ?? false) ||
        (fixtures?.asData?.value.isNotEmpty ?? false);

    // `refreshFeedsProvider` is a plain `Provider` of a function; watching it
    // keeps the pull-to-refresh callback out of a build-time `ref.read`.
    final Future<void> Function() onRefresh = ref.watch(refreshFeedsProvider);

    if (!hasContent && scoreboard.hasError) {
      return SlPageScaffold(
        title: 'Sports',
        onRefresh: onRefresh,
        slivers: <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorStateView(
              message: 'We could not load the sports feed right now.',
              onRetry: () {
                ref.invalidate(scoreboardProvider);
                ref.invalidate(categoryFeedProvider);
              },
            ),
          ),
        ],
      );
    }

    return SlPageScaffold(
      title: 'Sports',
      onRefresh: onRefresh,
      slivers: <Widget>[
        const SliverToBoxAdapter(child: ScoreboardStrip()),
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Following',
            onTap: () => context.go(AppRoutes.following),
          ),
        ),
        SliverToBoxAdapter(
          child: FollowedTeamsRow(
            targets: viewModel.followedSports,
            onTap: (FollowTarget _) => context.go(AppRoutes.following),
            onEmptyTap: () => context.go(AppRoutes.following),
          ),
        ),
        if (ad != null) _adSliver(context, ad),
        SliverToBoxAdapter(child: SectionHeader(title: viewModel.newsSectionTitle)),
        ..._newsSlivers(context, ref, news, liked),
        SliverToBoxAdapter(child: SectionHeader(title: viewModel.fixturesSectionTitle)),
        ..._fixtureSlivers(context, ref, fixtures, fixtureTeamId),
      ],
    );
  }

  /// Exactly one native-style inline unit, embedded in the stream right after
  /// the Following section. Renders nothing while the rotation is empty or
  /// still loading.
  Widget _adSliver(BuildContext context, AdUnit unit) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          0,
        ),
        child: AdCard(
          unit: unit,
          onCtaPressed: () => _showSnack(context, 'Sponsored by ${unit.advertiser}'),
          onOpened: (AdUnit opened) => _showSnack(context, 'Sponsored by ${opened.advertiser}'),
        ),
      ),
    );
  }

  /// Team news stream: the `sports` category feed rendered as article cards.
  List<Widget> _newsSlivers(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Article>> news,
    Set<String> liked,
  ) {
    return news.when(
      data: (List<Article> articles) {
        if (articles.isEmpty) {
          return <Widget>[_noticeSliver(context, 'No sports stories yet.')];
        }
        return <Widget>[
          SliverList.builder(
            itemCount: articles.length,
            itemBuilder: (BuildContext context, int index) {
              final Article article = articles[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: ArticleTile(
                  article: article,
                  isLiked: liked.contains(article.id),
                  onTap: () => context.push(AppRoutes.articleFor(article.id)),
                  onLike: () => unawaited(
                    ref.read(likesControllerProvider.notifier).toggle(article.id),
                  ),
                  onMore: (ArticleAction action) =>
                      _showSnack(context, '${action.label} · ${article.title}'),
                ),
              );
            },
          ),
        ];
      },
      loading: () => <Widget>[
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: ArticleTileSkeleton(),
          ),
        ),
      ],
      error: (Object error, StackTrace stack) => <Widget>[
        _noticeSliver(
          context,
          'Sports stories are unavailable right now.',
          onRetry: () => ref.invalidate(categoryFeedProvider),
        ),
      ],
    );
  }

  /// Fixtures & results for the followed team, ordered by the view model.
  List<Widget> _fixtureSlivers(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<GameScore>>? fixtures,
    String? teamId,
  ) {
    if (teamId == null || fixtures == null) {
      return <Widget>[
        _noticeSliver(context, 'Follow a team to see its fixtures and results.'),
      ];
    }
    return fixtures.when(
      data: (List<GameScore> games) {
        if (games.isEmpty) {
          return <Widget>[_noticeSliver(context, 'No fixtures scheduled yet.')];
        }
        return <Widget>[
          SliverList.list(
            children: <Widget>[
              for (final GameScore game in games)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: SportsFixtureRow(
                    game: game,
                    onTap: () => _showSnack(
                      context,
                      '${game.away.name} v ${game.home.name} · ${game.statusLabel}',
                    ),
                  ),
                ),
            ],
          ),
        ];
      },
      loading: () => <Widget>[
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: SkeletonBox(height: 72, borderRadius: AppRadius.cardRadius),
          ),
        ),
      ],
      error: (Object error, StackTrace stack) => <Widget>[
        _noticeSliver(
          context,
          'Fixtures are unavailable right now.',
          onRetry: () => ref.invalidate(teamGamesProvider(teamId)),
        ),
      ],
    );
  }

  /// Small in-stream surface used instead of a full-page error for one stream.
  Widget _noticeSliver(BuildContext context, String message, {VoidCallback? onRetry}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
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
                Icons.sports_soccer_outlined,
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
              if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }

  /// Confirmation surface for the tab's non-destructive actions.
  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
