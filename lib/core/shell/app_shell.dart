import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/auth/auth_repository.dart';
import '../domain/models/app_settings.dart';
import '../providers/auth_providers.dart';
import '../config/l10n.dart';
import '../providers/controllers.dart';
import '../routing/app_routes.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';

/// Persistent bottom navigation shell holding the four tab roots.
///
/// The bar mirrors the reference app: icon + label, selected item in full
/// contrast, unselected items muted, no indicator pill.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<_TabSpec> _tabs = <_TabSpec>[
    _TabSpec(icon: Icons.star_border, activeIcon: Icons.star),
    _TabSpec(icon: Icons.article_outlined, activeIcon: Icons.article),
    _TabSpec(
      icon: Icons.sports_basketball_outlined,
      activeIcon: Icons.sports_basketball,
    ),
    _TabSpec(icon: Icons.notifications_none, activeIcon: Icons.notifications),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // First-run gate: after sign-in, the topic/location picker must land before
    // the first personalised feed render.
    final AuthState auth = ref.watch(authControllerProvider);
    // The session restore is async. Treating `unknown` as anonymous made the
    // shell flash before a restored Clerk session arrived.
    if (auth.status == AuthStatus.unknown) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    final bool onboarded = ref.watch(
      settingsControllerProvider.select(
        (AppSettings settings) => settings.onboardingCompleted,
      ),
    );
    // First run is a device fact, not an identity fact: signed-out readers get
    // the same topic picker, and signing in later never reopens it.
    if (!onboarded) return const OnboardingPage();

    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;
    final List<String> labels = <String>[
      l10n.navForYou,
      l10n.navNews,
      l10n.navSports,
      l10n.navFollowing,
    ];
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
              for (int index = 0; index < _tabs.length; index++)
                NavigationDestination(
                  icon: Icon(_tabs[index].icon),
                  selectedIcon: Icon(_tabs[index].activeIcon),
                  label: labels[index],
                  tooltip: labels[index],
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
  const _TabSpec({required this.icon, required this.activeIcon});

  final IconData icon;
  final IconData activeIcon;
}

/// Navigation helpers shared by feature screens.
extension ArticleNavigation on BuildContext {
  void openArticle(String articleId) => push(AppRoutes.articleFor(articleId));

  void openSavedStories() => push(AppRoutes.saved);
}
