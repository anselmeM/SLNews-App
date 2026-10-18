import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Section header with the reference UI's trailing chevron, e.g.
/// "Top stories ›", "Cars and Vehicles ›", "Following ›".
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.lg,
      AppSpacing.md,
    ),
    this.compact = false,
  });

  final String title;

  /// Supporting line under the title, e.g. "Based on your interests".
  final String? subtitle;

  /// When set, the whole header (and chevron) becomes tappable.
  final VoidCallback? onTap;

  /// Extra widget before the chevron, e.g. a weather chip or "See all".
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  /// Uses the 19pt group title instead of the 24pt section title.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = compact
        ? context.typography.groupTitle
        : context.typography.sectionTitle;
    final Widget row = Row(
      children: <Widget>[
        // `Expanded`, not `Flexible` + `Spacer`: a Spacer is itself flexible, so
        // it took half the row and the title was laid out in what was left —
        // which is why "More in Top stories" came out as "More in Top st…".
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                  if (onTap != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.chevron_right,
                      size: compact ? 22 : 26,
                      color: context.colors.onSurface,
                    ),
                  ],
                ],
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.caption.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
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
