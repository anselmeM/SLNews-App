import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_routes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Entries in the page-level kebab menu.
///
/// The reference screen puts two destinations there — Settings and Notices — as
/// opposed to the story-level actions a card's menu offers.
enum PageMenuAction {
  settings,
  notices;

  String get label => switch (this) {
    PageMenuAction.settings => 'Settings',
    PageMenuAction.notices => 'Notices',
  };

  IconData get icon => switch (this) {
    PageMenuAction.settings => Icons.settings_outlined,
    PageMenuAction.notices => Icons.notifications_none,
  };
}

/// Kebab (⋮) affordance for a page header.
///
/// Without [onSelected] it renders the icon alone (for previews/skeletons). The
/// default selection behaviour is the reference one: Settings opens `/settings`,
/// Notices opens the notification history.
class PageMenuButton extends StatelessWidget {
  const PageMenuButton({
    super.key,
    this.onSelected,
    this.items = PageMenuAction.values,
    this.size = 22,
    this.color,
    this.tooltip = 'More options',
  });

  final ValueChanged<PageMenuAction>? onSelected;
  final List<PageMenuAction> items;
  final double size;
  final Color? color;
  final String tooltip;

  /// Navigates for [action]; exposed so a host can reuse the default routing.
  static void openDefault(BuildContext context, PageMenuAction action) {
    switch (action) {
      case PageMenuAction.settings:
        context.push(AppRoutes.settings);
      case PageMenuAction.notices:
        context.push(AppRoutes.notificationHistory);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color resolved = color ?? context.colors.onSurfaceVariant;
    final ValueChanged<PageMenuAction> handler =
        onSelected ?? (PageMenuAction action) => openDefault(context, action);

    return PopupMenuButton<PageMenuAction>(
      tooltip: tooltip,
      icon: Icon(Icons.more_vert, size: size, color: resolved),
      padding: EdgeInsets.zero,
      splashRadius: size + AppSpacing.sm,
      position: PopupMenuPosition.under,
      onSelected: handler,
      itemBuilder: (BuildContext context) => items
          .map(
            (PageMenuAction action) => PopupMenuItem<PageMenuAction>(
              value: action,
              height: 46,
              child: Row(
                children: <Widget>[
                  Icon(
                    action.icon,
                    size: 18,
                    color: context.colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(action.label, style: context.typography.button),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
