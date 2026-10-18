import 'package:flutter/material.dart';

import '../../../../core/domain/models/sports_models.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'team_crest.dart';

/// League table rendered on the league page and, compactly, on the Sports tab.
///
/// The reference groups sports content by competition and shows a table; the
/// standings data already existed but had no surface until now.
class StandingsTable extends StatelessWidget {
  const StandingsTable({
    super.key,
    required this.rows,
    this.onTeamTap,
    this.maxRows,
    this.showHeader = true,
  });

  final List<TeamStanding> rows;
  final ValueChanged<TeamStanding>? onTeamTap;

  /// Caps the table, e.g. the top five on the Sports tab.
  final int? maxRows;

  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final List<TeamStanding> visible = maxRows == null
        ? rows
        : rows.take(maxRows!).toList(growable: false);

    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          if (showHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 28),
                  Expanded(
                    child: Text(
                      'Team',
                      style: context.typography.overline.copyWith(
                        color: context.colors.onSurfaceFaint,
                      ),
                    ),
                  ),
                  Text(
                    'Record',
                    style: context.typography.overline.copyWith(
                      color: context.colors.onSurfaceFaint,
                    ),
                  ),
                ],
              ),
            ),
          for (int index = 0; index < visible.length; index++) ...<Widget>[
            if (index > 0)
              Divider(height: 1, thickness: 1, color: context.colors.divider),
            _StandingRow(
              standing: visible[index],
              onTap: onTeamTap == null
                  ? null
                  : () => onTeamTap!(visible[index]),
            ),
          ],
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.standing, this.onTap});

  final TeamStanding standing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Text(
              '${standing.rank}',
              style: context.typography.body.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          TeamCrest(
            name: standing.team.name,
            logoUrl: standing.team.logoUrl,
            colourHex: standing.team.colourHex,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              standing.team.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.body,
            ),
          ),
          Text(
            standing.record,
            style: context.typography.caption.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          if (onTap != null) ...<Widget>[
            const SizedBox(width: AppSpacing.xxs),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: context.colors.onSurfaceFaint,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: '${standing.rank}. ${standing.team.name}, ${standing.record}',
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
