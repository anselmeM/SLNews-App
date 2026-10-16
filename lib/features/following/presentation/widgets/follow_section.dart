import 'package:flutter/material.dart';

import '../../../../core/domain/models/follow_models.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// A titled white card group in the Following tab ("Sports", "Locations",
/// "Most popular with users", "Topics").
///
/// Renders one [FollowRow] per [targets] entry, separated by hairline dividers
/// *inside* the card, so a group reads as a single 16pt-radius surface. The
/// caller supplies row internals through [rowBuilder] and therefore keeps the
/// screen-specific chrome (chips, chevrons) out of this widget.
class FollowSection extends StatelessWidget {
  const FollowSection({
    super.key,
    required this.targets,
    required this.rowBuilder,
    this.leading,
    this.footer,
  });

  /// Entities to render, already grouped and sorted by the view model.
  final List<FollowTarget> targets;

  /// Builds the row body for one target.
  final Widget Function(BuildContext context, FollowTarget target) rowBuilder;

  /// Optional label above the card, e.g. the muted "Most popular with users"
  /// overline. Section headers stay with the caller so headers and cards keep
  /// their own vertical rhythm.
  final Widget? leading;

  /// Optional widget rendered under the card, e.g. a caption or retry action.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ?leading,
        Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: AppRadius.cardRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              for (int index = 0; index < targets.length; index++) ...<Widget>[
                if (index > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: context.colors.divider,
                  ),
                rowBuilder(context, targets[index]),
              ],
            ],
          ),
        ),
        ?footer,
      ],
    );
  }
}

/// Muted uppercase-ish label used by the "Most popular with users" group.
///
/// Deliberately *not* a [SectionHeader]: the reference screen shows this group
/// as a quiet caption rather than a 24pt tappable section title.
class FollowGroupLabel extends StatelessWidget {
  const FollowGroupLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Text(label, style: context.typography.overline),
    );
  }
}
