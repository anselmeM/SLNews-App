import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/header_actions.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ads/sponsorship_launcher.dart';
import '../../../core/domain/models/ad_placement.dart';
import '../../../core/domain/models/ad_unit.dart';
import '../../../core/domain/models/article.dart';
import '../../../core/domain/models/follow_models.dart';
import '../../../core/data/sources/espn_source.dart';
import '../../../core/domain/models/sports_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tracked_ad_card.dart';
import '../../../core/widgets/article_tile.dart';
import '../../../core/widgets/publisher_mark.dart';
import '../../../core/widgets/sl_network_image.dart';
import '../../../core/widgets/overflow_menu_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/sl_page_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import 'viewmodels/sports_view_model.dart';
import '../../feed/presentation/widgets/article_actions.dart';
import '../domain/sports_links.dart';
import '../domain/sports_league_catalog.dart';
import '../../../core/data/sources/league_news_source.dart';
import 'widgets/followed_teams_row.dart';
import 'widgets/scoreboard_strip.dart';
import 'widgets/sports_league_section.dart';
import 'widgets/sports_fixture_row.dart';

part 'sports_sections.dart';

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
    final AsyncValue<ScoreboardSnapshot> scoreboard = ref.watch(
      scoreboardProvider,
    );
    final AsyncValue<List<Article>> allSports = ref.watch(
      categoryFeedProvider('sports'),
    );
    final FollowingSnapshot following = ref.watch(followingControllerProvider);
    final SportsViewModel viewModel = SportsViewModel.from(
      snapshot: scoreboard.asData?.value,
      following: following,
    );
    final String? heroTeamId = viewModel.heroTeam?.id;
    final bool hasTeamNews =
        heroTeamId != null && EspnSource.supportsTeamId(heroTeamId);
    final AsyncValue<List<Article>> teamNews = hasTeamNews
        ? ref.watch(teamNewsProvider(heroTeamId))
        : allSports;
    final AsyncValue<List<AdUnit>> ads = ref.watch(
      adUnitsProvider(AdPlacement.sportsStream.wire),
    );
    final Set<String> liked = ref.watch(likesControllerProvider);

    final String? fixtureTeamId = viewModel.heroTeam?.id;
    final AsyncValue<List<GameScore>>? fixtures = fixtureTeamId == null
        ? null
        : ref.watch(teamGamesProvider(fixtureTeamId));

    final List<AdUnit> adUnits = ads.asData?.value ?? const <AdUnit>[];
    final AdUnit? ad = adUnits.isEmpty ? null : adUnits.first;

    final bool hasContent =
        viewModel.hasGames ||
        viewModel.hasFollowedSports ||
        (allSports.asData?.value.isNotEmpty ?? false) ||
        (teamNews.asData?.value.isNotEmpty ?? false) ||
        (fixtures?.asData?.value.isNotEmpty ?? false);

    final Future<void> Function() onRefresh = ref.watch(refreshFeedsProvider);

    final Widget content = (!hasContent && scoreboard.hasError)
        ? SlPageScaffold(
            title: 'Sports',
            actions: const <Widget>[HeaderActions()],
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
          )
        : SlPageScaffold(
            title: 'Sports',
            actions: const <Widget>[HeaderActions()],
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
                  onTap: (FollowTarget target) {
                    switch (target.kind) {
                      case FollowKind.team:
                        context.push(
                          AppRoutes.teamFor(target.id),
                          extra: target.label,
                        );
                      case FollowKind.league:
                        context.push(
                          AppRoutes.leagueFor(target.id),
                          extra: target.label,
                        );
                      default:
                        context.go(AppRoutes.following);
                    }
                  },
                  onEmptyTap: () => context.go(AppRoutes.following),
                ),
              ),
              if (ad != null) _adSliver(context, ref, ad),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Top stories',
                  onTap: () => context.go(AppRoutes.news),
                ),
              ),
              ..._topStoriesSlivers(context, ref, allSports, liked),
              ..._leagueSections(context, ref, viewModel, teamNews, following),
              SliverToBoxAdapter(
                child: SectionHeader(title: viewModel.newsSectionTitle),
              ),
              ..._newsSlivers(context, ref, allSports, liked),
              SliverToBoxAdapter(
                child: SectionHeader(title: viewModel.fixturesSectionTitle),
              ),
              ..._fixtureSlivers(
                context,
                ref,
                fixtures,
                fixtureTeamId,
                viewModel.heroTeam?.label,
              ),
            ],
          );

    // Follow the reader's theme; the league blocks keep their own dark artwork.
    return content;
  }

  /// Top stories: one full-bleed hero followed by compact story cards.
  List<Widget> _topStoriesSlivers(
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
          SliverToBoxAdapter(
            child: _TopStoryHero(
              article: articles.first,
              onTap: () => _openArticle(context, articles.first),
            ),
          ),
          for (final Article article in articles.skip(1).take(4))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: ArticleTile(
                  article: article,
                  isLiked: liked.contains(article.id),
                  onTap: () => _openArticle(context, article),
                  onLike: () {},
                  onMore: (ArticleAction action) =>
                      handleArticleAction(context, ref, article, action),
                ),
              ),
            ),
        ];
      },
      loading: () => <Widget>[
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SkeletonBox(height: 220, borderRadius: AppRadius.cardRadius),
          ),
        ),
      ],
      error: (Object error, StackTrace stack) => <Widget>[
        _noticeSliver(context, 'Sports stories are unavailable right now.'),
      ],
    );
  }

  /// One block per league present in the scoreboard, Samsung style.
  List<Widget> _leagueSections(
    BuildContext context,
    WidgetRef ref,
    SportsViewModel viewModel,
    AsyncValue<List<Article>> teamNews,
    FollowingSnapshot following,
  ) {
    final Map<String, List<GameScore>> groups = <String, List<GameScore>>{};
    for (final GameScore game in viewModel.ordered) {
      // A provider may label a European fixture with its own competition name;
      // fold it onto the merged section so one block renders, not five.
      final String label =
          mergedLeagueLabelFor(game.leagueLabel) ?? game.leagueLabel;
      groups.putIfAbsent(label, () => <GameScore>[]).add(game);
    }

    // Team news is used only when ESPN confirms it belongs to the followed
    // team's league (Lakers -> NBA). There is no generic-sports fallback here.
    final List<Article> specific = teamNews.asData?.value ?? const <Article>[];
    final String? heroLeague = viewModel.heroTeam == null
        ? null
        : EspnSource.leagueIdForTeam(viewModel.heroTeam!.id);
    // The curated catalogue is the feed's minimum coverage. Scoreboard groups
    // for leagues outside it are appended, so a new provider league still shows.
    final Set<String> labelSet = <String>{
      for (final SportsLeague league in kFeaturedSportsLeagues) league.label,
      ...groups.keys,
    };
    final List<String> labels = labelSet.toList(growable: false)
      ..sort((String a, String b) {
        final int left = featuredLeagueOrder(a);
        final int right = featuredLeagueOrder(b);
        return left != right ? left.compareTo(right) : a.compareTo(b);
      });
    return <Widget>[
      SliverList.builder(
        itemCount: labels.length,
        itemBuilder: (BuildContext context, int index) {
          final String label = labels[index];
          final List<GameScore> games = groups[label] ?? const <GameScore>[];
          final String slug =
              featuredLeagueId(label) ?? SportsLinks.leagueIdForLabel(label);
          final FollowTarget target = FollowTarget(
            id: 'league:$slug',
            kind: FollowKind.league,
            label: label,
          );
          final bool useSpecific = heroLeague != null && heroLeague == slug;
          return SportsLeagueSection(
            leagueLabel: label,
            leagueId: slug,
            games: games,
            preferredArticles: useSpecific
                ? specific.take(4).toList(growable: false)
                : const <Article>[],
            isFollowing: following.isFollowed(target.id),
            onToggleFollow: () =>
                ref.read(followingControllerProvider.notifier).toggle(target),
            onArticleTap: (Article article) => _openArticle(context, article),
            onMore: () => context.push(AppRoutes.leagueFor(slug), extra: label),
            onLeagueTap: () =>
                context.push(AppRoutes.leagueFor(slug), extra: label),
            onGameTap: (GameScore game) =>
                context.push(AppRoutes.leagueFor(slug), extra: label),
          );
        },
      ),
    ];
  }

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
                  onTap: () => _openArticle(context, article),
                  onLike: () => unawaited(
                    ref
                        .read(likesControllerProvider.notifier)
                        .toggle(article.id),
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
    String? teamLabel,
  ) {
    if (teamId == null || fixtures == null) {
      return <Widget>[
        _noticeSliver(
          context,
          'Follow a team to see its fixtures and results.',
        ),
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
                    onTap: () => context.push(
                      AppRoutes.teamFor(game.home.id),
                      extra: game.home.name,
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
  /// ESPN stories are external: open them in the browser, not the in-app
  /// reader (which only knows SLNews article ids).
  void _openArticle(BuildContext context, Article article) {
    final String? sourceUrl = article.sourceUrl;
    if (isExternalSportsArticle(article) && sourceUrl != null) {
      unawaited(
        launchUrl(Uri.parse(sourceUrl), mode: LaunchMode.externalApplication),
      );
      return;
    }
    context.push(AppRoutes.articleFor(article.id));
  }
}
