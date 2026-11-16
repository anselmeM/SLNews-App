import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_glyphs.dart';

/// Card that groups catalogue rows with hairline dividers.
///
/// Every "Manage ..." screen in the reference puts its options in one rounded
/// card rather than a bare list, which is what makes the checkmarks read as a
/// single multi-select control instead of separate buttons.
class CatalogueCard extends StatelessWidget {
  const CatalogueCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int index = 0; index < children.length; index++) ...<Widget>[
            if (index > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: AppSpacing.lg,
                color: context.colors.divider,
              ),
            children[index],
          ],
        ],
      ),
    );
  }
}

/// The leading selection circle: a primary check when selected, otherwise the
/// row's own glyph (or initials) on a muted disc.
///
/// Extracted so a merged-league row can keep the tick as its own tap target
/// while the rest of the row expands to list what the section contains.
class CatalogueCheckCircle extends StatelessWidget {
  const CatalogueCheckCircle({
    super.key,
    required this.label,
    required this.isSelected,
    this.icon,
    this.initials,
    this.onTap,
  });

  final String label;
  final bool isSelected;
  final IconData? icon;
  final String? initials;

  /// When set, only the circle follows/unfollows (the row body does something
  /// else, e.g. expand).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget circle = Container(
      width: CatalogueCheckRow.circleSize,
      height: CatalogueCheckRow.circleSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected
            ? context.colors.primary
            : context.colors.surfaceMuted,
        shape: BoxShape.circle,
      ),
      child: isSelected
          ? Icon(Icons.check, size: 22, color: context.colors.onPrimary)
          : (icon != null
                ? Icon(icon, size: 20, color: context.colors.onSurface)
                : Text(
                    initials ?? AppGlyphs.initials(label),
                    style: context.typography.overline.copyWith(
                      color: context.colors.onSurface,
                    ),
                  )),
    );
    if (onTap == null) return circle;
    return Semantics(
      button: true,
      toggled: isSelected,
      label: isSelected ? 'Unfollow $label' : 'Follow $label',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: circle,
      ),
    );
  }
}

/// One selectable catalogue row: a leading check circle, a label and an
/// optional subtitle, with the whole row acting as the toggle.
///
/// Followed rows show a filled primary circle with a check — the reference's
/// affordance — while unfollowed rows show their topic/league glyph in a muted
/// circle, so the list still says *what* each option is before it is selected.
class CatalogueCheckRow extends StatelessWidget {
  const CatalogueCheckRow({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.initials,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? subtitle;
  final IconData? icon;
  final String? initials;

  static const double circleSize = 40;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: isSelected,
      label: isSelected ? 'Unfollow $label' : 'Follow $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              CatalogueCheckCircle(
                label: label,
                isSelected: isSelected,
                icon: icon,
                initials: initials,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.groupTitle,
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.caption,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
