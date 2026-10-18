import 'package:flutter/material.dart';

import '../domain/models/news_category.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_glyphs.dart';
import 'pressable_ink_well.dart';
import '../utils/motion.dart';

/// A single category filter pill.
///
/// Selected pills invert to near-black (light mode) exactly like the
/// "Cars and Vehicles" pill in the reference screens.
class CategoryPill extends StatelessWidget {
  const CategoryPill({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Optional leading icon drawn inside a circular chip.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color background = selected
        ? context.colors.surfaceInverse
        : context.colors.surface;
    final Color foreground = selected
        ? context.colors.onSurfaceInverse
        : context.colors.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        // Selecting a pill cross-fades between the light and inverse fills
        // instead of swapping them abruptly; the tap also dips the pill.
        duration: motionDuration(context, AppMotion.fast),
        curve: AppMotion.standard,
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.pillRadius,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.pillRadius,
          clipBehavior: Clip.antiAlias,
          child: PressableInkWell(
            onTap: onTap,
            borderRadius: AppRadius.pillRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? foreground
                            : context.colors.surfaceMuted,
                      ),
                      child: Icon(
                        icon,
                        size: 15,
                        color: selected ? background : context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    label,
                    style: context.typography.chip.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrollable category strip used at the top of the News tab.
class CategoryPillStrip extends StatelessWidget {
  const CategoryPillStrip({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    this.showIcons = false,
    this.controller,
  });

  final List<NewsCategory> categories;
  final String selectedId;
  final ValueChanged<NewsCategory> onSelected;
  final EdgeInsetsGeometry padding;
  final bool showIcons;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: categories.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) {
          final NewsCategory category = categories[index];
          return CategoryPill(
            label: category.label,
            selected: category.id == selectedId,
            icon: showIcons ? AppGlyphs.category(category.icon) : null,
            onTap: () => onSelected(category),
          );
        },
      ),
    );
  }
}
