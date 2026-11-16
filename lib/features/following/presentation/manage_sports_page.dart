import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/follow_models.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_glyphs.dart';
import '../../../core/widgets/state_views.dart';
import '../../sports/domain/sports_league_catalog.dart';
import 'widgets/catalogue_list.dart';
import 'widgets/follow_section.dart';

/// "Manage leagues and teams": the sports following surface.
///
/// The Following tab's Sports header used to jump to the Sports tab, so there
/// was no way to add a competition — the only followable leagues were the three
/// seeded ones. This screen lists every featured league plus the seeded teams,
/// and a followed league with no seed entry is persisted by the repository.
///
/// "European Leagues" stays a single followable section, matching the Sports
/// feed's merged block; tapping it reveals the four competitions it contains,
/// each of which opens its own league page.
class ManageSportsPage extends ConsumerStatefulWidget {
  const ManageSportsPage({super.key});

  @override
  ConsumerState<ManageSportsPage> createState() => _ManageSportsPageState();
}

class _ManageSportsPageState extends ConsumerState<ManageSportsPage> {
  String _query = '';

  /// Merged league ids currently expanded to show their members.
  final Set<String> _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final FollowingSnapshot snapshot = ref.watch(followingControllerProvider);

    final List<FollowTarget> leagues = <FollowTarget>[
      for (final SportsLeague league in kFeaturedSportsLeagues)
        _leagueTarget(snapshot, league),
    ];
    final List<FollowTarget> teams =
        snapshot.sports
            .where((FollowTarget t) => t.kind == FollowKind.team)
            .toList()
          ..sort(
            (FollowTarget a, FollowTarget b) => a.label.compareTo(b.label),
          );

    final String query = _query.trim().toLowerCase();
    bool matches(FollowTarget target) =>
        query.isEmpty || target.label.toLowerCase().contains(query);

    final List<FollowTarget> visibleLeagues = leagues.where(matches).toList();
    final List<FollowTarget> visibleTeams = teams.where(matches).toList();

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
        title: Text(
          'Manage leagues and teams',
          style: context.typography.groupTitle,
        ),
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
              'Select the leagues and teams you want to follow.',
              style: context.typography.caption,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: TextField(
              onChanged: (String value) => setState(() => _query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search leagues and teams',
              ),
            ),
          ),
          Expanded(
            child: visibleLeagues.isEmpty && visibleTeams.isEmpty
                ? const EmptyStateView(
                    title: 'No leagues or teams found',
                    message: 'Try another name.',
                    icon: Icons.search_off,
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    children: <Widget>[
                      if (visibleLeagues.isNotEmpty) ...<Widget>[
                        const FollowGroupLabel(label: 'Leagues'),
                        CatalogueCard(
                          children: <Widget>[
                            for (final FollowTarget target in visibleLeagues)
                              _row(snapshot, target),
                          ],
                        ),
                      ],
                      if (visibleTeams.isNotEmpty) ...<Widget>[
                        const FollowGroupLabel(label: 'Teams'),
                        CatalogueCard(
                          children: <Widget>[
                            for (final FollowTarget target in visibleTeams)
                              _row(snapshot, target),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(FollowingSnapshot snapshot, FollowTarget target) {
    final List<SportsLeague> members = mergedLeagueMembers(_slug(target.id));
    if (members.isNotEmpty) return _mergedLeagueRow(snapshot, target, members);

    final bool isTeam = target.kind == FollowKind.team;
    return CatalogueCheckRow(
      label: target.label,
      subtitle: target.subtitle,
      isSelected: snapshot.isFollowed(target.id),
      icon: isTeam ? null : AppGlyphs.follow(FollowKind.league),
      initials: isTeam ? AppGlyphs.initials(target.label) : null,
      onTap: () =>
          ref.read(followingControllerProvider.notifier).toggle(target),
    );
  }

  /// "European Leagues" is one followable section, so the tick follows the
  /// section as a whole; the rest of the row expands to name the competitions
  /// inside it, and each name opens that league's page.
  Widget _mergedLeagueRow(
    FollowingSnapshot snapshot,
    FollowTarget target,
    List<SportsLeague> members,
  ) {
    final bool expanded = _expanded.contains(target.id);
    final bool selected = snapshot.isFollowed(target.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InkWell(
          onTap: () => setState(() {
            if (!_expanded.remove(target.id)) _expanded.add(target.id);
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                CatalogueCheckCircle(
                  label: target.label,
                  isSelected: selected,
                  icon: AppGlyphs.follow(FollowKind.league),
                  onTap: () => ref
                      .read(followingControllerProvider.notifier)
                      .toggle(target),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        target.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.groupTitle,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'One section · ${members.length} leagues',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.caption,
                      ),
                    ],
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 22,
                  color: context.colors.onSurfaceFaint,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
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
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg +
                        CatalogueCheckRow.circleSize +
                        AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          member.label,
                          style: context.typography.body,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: context.colors.onSurfaceFaint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }

  /// `league:european-leagues` -> `european-leagues`.
  String _slug(String id) {
    final int separator = id.indexOf(':');
    return separator < 0 ? id : id.substring(separator + 1);
  }

  /// Reuses the seeded target when the catalogue carries the league (so its
  /// subtitle survives), otherwise builds one for a featured league.
  FollowTarget _leagueTarget(FollowingSnapshot snapshot, SportsLeague league) {
    final String id = 'league:${league.id}';
    for (final FollowTarget target in snapshot.sports) {
      if (target.id == id) return target;
    }
    return FollowTarget(
      id: id,
      kind: FollowKind.league,
      label: league.label,
      subtitle: 'League',
    );
  }
}
