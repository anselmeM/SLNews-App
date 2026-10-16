import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Section header with the reference UI's trailing chevron, e.g.
/// "Top stories ›", "Cars and Vehicles ›", "Following ›".
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onTap,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
    this.compact = false,
  });

  final String title;

  /// When set, the whole header (and chevron) becomes tappable.
  final VoidCallback? onTap;

  /// Extra widget before the chevron, e.g. a weather chip or "See all".
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  /// Uses the 19pt group title instead of the 24pt section title.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = compact ? context.typography.groupTitle : context.typography.sectionTitle;
    final Widget row = Row(
      children: <Widget>[
        Flexible(
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ),
        if (onTap != null) ...<Widget>[
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right, size: compact ? 22 : 26, color: context.colors.onSurface),
        ],
        const Spacer(),
        ?trailing,
      ],
    );

    if (onTap == null) {
      return Padding(padding: padding, child: row);
    }
    return InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: row),
    );
  }
}
