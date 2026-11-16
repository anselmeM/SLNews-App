import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/follow_models.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/state_views.dart';
import '../../sports/domain/sports_league_catalog.dart';
import '../../sports/domain/sports_links.dart';
import 'widgets/catalogue_list.dart';

/// One competition's teams, reached from the "Manage leagues and teams" list.
///
/// This is the reference's league → team drill-in: the league row keeps the
/// follow tick, and its chevron opens this page to pick individual clubs.
///
/// A merged competition ("European Leagues") has no single team list — its four
/// member leagues do — so it lists those instead, each opening its league page.
class ManageLeagueTeamsPage extends ConsumerWidget {
  const ManageLeagueTeamsPage({super.key, required this.leagueId, this.label});

  final String leagueId;

  /// Label carried by the pushing row; falls back to the id-derived name for
  /// deep links.
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FollowingSnapshot snapshot = ref.watch(followingControllerProvider);
    final String title = label ?? SportsLinks.leagueLabelForId(leagueId);
    final List<SportsLeague> members = mergedLeagueMembers(leagueId);
    final List<FollowTarget> teams = _teamsFor(snapshot);

    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        backgroundColor: context.colors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: Text(title, style: context.typography.groupTitle),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Text(
              members.isEmpty
                  ? 'Select the teams you want to follow.'
                  : 'Followed as one section. Pick a league to see its page.',
              style: context.typography.caption,
            ),
          ),
          Expanded(
            child: members.isNotEmpty
                ? _memberList(context, members)
                : (teams.isEmpty
                      ? EmptyStateView(
                          title: 'No teams listed yet',
                          message:
                              'This competition has no seeded teams. Open the '
                              'league page to follow its scores instead.',
                          actionLabel: 'Open league page',
                          onAction: () => context.push(
                            AppRoutes.leagueFor(leagueId),
                            extra: title,
                          ),
                          icon: Icons.groups_outlined,
                        )
                      : _teamList(ref, snapshot, teams)),
          ),
        ],
      ),
    );
  }

  Widget _memberList(BuildContext context, List<SportsLeague> members) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: <Widget>[
        CatalogueCard(
          children: <Widget>[
            for (final SportsLeague member in members)
              Semantics(
                button: true,
                label: 'Open ${member.label}',
                child: InkWell(
                  onTap: () => context.push(
                    AppRoutes.leagueFor(member.id),
                    extra: member.label,
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
                            member.label,
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
        ),
      ],
    );
  }

  Widget _teamList(
    WidgetRef ref,
    FollowingSnapshot snapshot,
    List<FollowTarget> teams,
  ) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: <Widget>[
        CatalogueCard(
          children: <Widget>[
            for (final FollowTarget team in teams)
              CatalogueCheckRow(
                label: team.label,
                subtitle: team.subtitle,
                isSelected: snapshot.isFollowed(team.id),
                onTap: () =>
                    ref.read(followingControllerProvider.notifier).toggle(team),
              ),
          ],
        ),
      ],
    );
  }

  /// Seeded teams whose subtitle names this competition (`Basketball · NBA`).
  ///
  /// Team targets carry no league id, and the alternative — a hard-coded map —
  /// would drift from the seed the moment a team is added.
  List<FollowTarget> _teamsFor(FollowingSnapshot snapshot) {
    final String slug = leagueId;
    final List<FollowTarget> teams = snapshot.sports
        .where((FollowTarget target) => target.kind == FollowKind.team)
        .where((FollowTarget target) {
          final String? league = _leagueLabelOf(target);
          if (league == null) return false;
          return SportsLinks.leagueIdForLabel(league) == slug;
        })
        .toList(growable: false);
    teams.sort(
      (FollowTarget a, FollowTarget b) =>
          a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return teams;
  }

  /// "Basketball · NBA" -> "NBA".
  String? _leagueLabelOf(FollowTarget team) {
    final String? subtitle = team.subtitle;
    if (subtitle == null) return null;
    final int separator = subtitle.lastIndexOf('·');
    if (separator < 0) return null;
    final String label = subtitle.substring(separator + 1).trim();
    return label.isEmpty ? null : label;
  }
}
