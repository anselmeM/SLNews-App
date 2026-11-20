import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Actions offered by the kebab menu on feed cards and in the reader.
enum ArticleAction {
  bookmark,
  removeBookmark,
  share,
  openInBrowser,
  followPublisher;

  String get label => switch (this) {
    ArticleAction.bookmark => 'Save story',
    ArticleAction.removeBookmark => 'Remove from saved',
    ArticleAction.share => 'Share',
    ArticleAction.openInBrowser => 'Open in browser',
    ArticleAction.followPublisher => 'Follow publisher',
  };

  IconData get icon => switch (this) {
    ArticleAction.bookmark => Icons.bookmark_add_outlined,
    ArticleAction.removeBookmark => Icons.bookmark_remove_outlined,
    ArticleAction.share => Icons.ios_share,
    ArticleAction.openInBrowser => Icons.open_in_new,
    ArticleAction.followPublisher => Icons.add_circle_outline,
  };
}

/// Kebab (⋮) affordance matching the reference cards' "more" control.
class OverflowMenuButton extends StatelessWidget {
  const OverflowMenuButton({
    super.key,
    this.onSelected,
    this.items = const <ArticleAction>[
      ArticleAction.bookmark,
      ArticleAction.share,
      ArticleAction.openInBrowser,
    ],
    this.size = 20,
    this.color,
    this.tooltip = 'More options',
  });

  final ValueChanged<ArticleAction>? onSelected;
  final List<ArticleAction> items;
  final double size;
  final Color? color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final Color resolved = color ?? context.colors.onSurfaceVariant;
    if (onSelected == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Icon(Icons.more_vert, size: size, color: resolved),
      );
    }
    return PopupMenuButton<ArticleAction>(
      tooltip: tooltip,
      icon: Icon(Icons.more_vert, size: size, color: resolved),
      padding: EdgeInsets.zero,
      splashRadius: size + AppSpacing.sm,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => items
          .map(
            (ArticleAction action) => PopupMenuItem<ArticleAction>(
              value: action,
              height: 44,
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
