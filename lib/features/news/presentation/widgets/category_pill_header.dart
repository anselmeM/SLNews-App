import 'package:flutter/material.dart';

import '../../../../core/domain/models/news_category.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/category_pills.dart';

/// Height reserved for the pinned pill strip under the News app bar.
const double kCategoryPillHeaderHeight = 56;

/// The pinned category selector that sits under the News app bar.
///
/// [SlPageScaffold] hands this to `SliverAppBar.bottom`, so it stays pinned
/// while the article stream scrolls underneath it. A `canvas`-coloured band is
/// painted behind the pills so article cards never show through the gap above
/// and below the 46pt-tall strip.
class CategoryPillHeader extends StatelessWidget implements PreferredSizeWidget {
  const CategoryPillHeader({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    this.controller,
    this.showIcons = false,
  });

  /// Categories in catalogue order, i.e. `NewsCategories.all`.
  final List<NewsCategory> categories;

  /// Id of the currently selected category.
  final String selectedId;

  /// Called with the tapped category; the page owns the selection state.
  final ValueChanged<NewsCategory> onSelected;

  /// Optional controller so the page can keep the selected pill on screen.
  final ScrollController? controller;

  /// Reserved for the Sports/topic variants that draw a leading icon.
  final bool showIcons;

  @override
  Size get preferredSize => const Size.fromHeight(kCategoryPillHeaderHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kCategoryPillHeaderHeight,
      color: context.colors.canvas,
      alignment: Alignment.center,
      child: CategoryPillStrip(
        categories: categories,
        selectedId: selectedId,
        onSelected: onSelected,
        showIcons: showIcons,
        controller: controller,
      ),
    );
  }
}
