import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_routes.dart';

/// Persistent bottom navigation shell holding the four tab roots.
///
/// The bar mirrors the reference app: icon + label, selected item in full
/// contrast, unselected items muted, no indicator pill.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<_TabSpec> _tabs = <_TabSpec>[
    _TabSpec(label: 'For you', icon: Icons.star_border, activeIcon: Icons.star),
    _TabSpec(
      label: 'News',
      icon: Icons.article_outlined,
      activeIcon: Icons.article,
    ),
    _TabSpec(
      label: 'Sports',
      icon: Icons.sports_basketball_outlined,
      activeIcon: Icons.sports_basketball,
    ),
    _TabSpec(
      label: 'Following',
      icon: Icons.notifications_none,
      activeIcon: Icons.notifications,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.dividerColor, width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onDestinationSelected,
            destinations: <Widget>[
              for (final _TabSpec tab in _tabs)
                NavigationDestination(
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(tab.activeIcon),
                  label: tab.label,
                  tooltip: tab.label,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onDestinationSelected(int index) {
    // Tapping the active tab resets that branch to its root.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _TabSpec {
  const _TabSpec({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Navigation helpers shared by feature screens.
extension ArticleNavigation on BuildContext {
  void openArticle(String articleId) => push(AppRoutes.articleFor(articleId));

  void openSavedStories() => push(AppRoutes.saved);
}
