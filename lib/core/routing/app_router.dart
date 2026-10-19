import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/article/presentation/article_page.dart';
import '../../features/article/presentation/article_web_page.dart';
import '../../features/auth/presentation/account_page.dart';
import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/bookmarks/presentation/saved_stories_page.dart';
import '../../features/feed/presentation/for_you_page.dart';
import '../../features/following/presentation/following_page.dart';
import '../../features/following/presentation/manage_sources_page.dart';
import '../../features/following/presentation/manage_topics_page.dart';
import '../../features/following/presentation/notification_history_page.dart';
import '../../features/news/presentation/news_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/sports/presentation/league_page.dart';
import '../../features/sports/presentation/sports_page.dart';
import '../../features/sports/presentation/team_page.dart';
import '../../features/video/presentation/video_reel_page.dart';
import '../shell/app_shell.dart';
import 'app_routes.dart';
import '../../features/markets/presentation/stocks_page.dart';
import '../../features/search/presentation/search_page.dart';
import '../../features/feed/presentation/top_stories_section_page.dart';

/// The app router: a stateful shell with four persistent branches plus the
/// reader and saved-stories routes pushed above the navigation bar.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>(
  (Ref ref) => createAppRouter(),
  name: 'appRouter',
);

GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.forYou,
    debugLogDiagnostics: false,
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        redirect: (BuildContext context, GoRouterState state) =>
            AppRoutes.forYou,
      ),
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) {
              return AppShell(navigationShell: navigationShell);
            },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.forYou,
                name: RouteNames.forYou,
                builder: (BuildContext context, GoRouterState state) =>
                    const ForYouPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.news,
                name: RouteNames.news,
                builder: (BuildContext context, GoRouterState state) =>
                    const NewsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.sports,
                name: RouteNames.sports,
                builder: (BuildContext context, GoRouterState state) =>
                    const SportsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.following,
                name: RouteNames.following,
                builder: (BuildContext context, GoRouterState state) =>
                    const FollowingPage(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'notifications',
                    name: RouteNames.notificationHistory,
                    builder: (BuildContext context, GoRouterState state) =>
                        const NotificationHistoryPage(),
                  ),
                  GoRoute(
                    path: 'sources',
                    name: RouteNames.manageSources,
                    builder: (BuildContext context, GoRouterState state) =>
                        const ManageSourcesPage(),
                  ),
                  GoRoute(
                    path: 'topics',
                    name: RouteNames.manageTopics,
                    builder: (BuildContext context, GoRouterState state) =>
                        const ManageTopicsPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '${AppRoutes.article}/:id',
        name: RouteNames.article,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          return ArticlePage(articleId: state.pathParameters['id'] ?? '');
        },
      ),
      GoRoute(
        path: '${AppRoutes.article}/:id/original',
        name: RouteNames.articleOriginal,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          return ArticleWebPage(articleId: state.pathParameters['id'] ?? '');
        },
      ),
      GoRoute(
        path: AppRoutes.saved,
        name: RouteNames.saved,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const SavedStoriesPage(),
      ),
      GoRoute(
        path: AppRoutes.account,
        name: RouteNames.account,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const AccountPage(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        name: RouteNames.signIn,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const SignInPage(),
      ),
      GoRoute(
        path: '${AppRoutes.video}/:id',
        name: RouteNames.video,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            VideoReelRoute(videoId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '${AppRoutes.league}/:id',
        name: RouteNames.league,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final Object? extra = state.extra;
          return LeaguePage(
            leagueId: state.pathParameters['id'] ?? '',
            leagueLabel: extra is String ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.team}/:id',
        name: RouteNames.team,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final Object? extra = state.extra;
          return TeamPage(
            teamId: state.pathParameters['id'] ?? '',
            teamName: extra is String ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.section}/:id',
        name: RouteNames.section,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final String id = state.pathParameters['id'] ?? '';
          final Object? extra = state.extra;
          return TopStoriesSectionPage(
            categoryId: id,
            title: extra is String && extra.trim().isNotEmpty
                ? extra
                : TopStoriesSectionPage.titleFromId(id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.topStories,
        name: RouteNames.topStories,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const TopStoriesSectionPage(),
      ),
      GoRoute(
        path: AppRoutes.search,
        name: RouteNames.search,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const SearchPage(),
      ),
      GoRoute(
        path: AppRoutes.stocks,
        name: RouteNames.stocks,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const StocksPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: RouteNames.settings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsPage(),
      ),
    ],
  );
}

/// Root navigator so pushed routes cover the bottom navigation shell.
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
