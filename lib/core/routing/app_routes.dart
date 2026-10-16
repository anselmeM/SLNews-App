/// Route paths for SLNews.
///
/// The four tab roots are stable, deep-linkable URLs (the cross-platform
/// contract required by the spec); `/article/:id` and `/saved` are pushed above
/// the bottom-navigation shell.
abstract final class AppRoutes {
  static const String forYou = '/for_you';
  static const String news = '/news';
  static const String sports = '/sports';
  static const String following = '/following';

  static const String article = '/article';
  static const String saved = '/saved';

  /// Identity surface, pushed above the shell so it covers the navigation bar.
  static const String signIn = '/sign_in';

  /// Notification history, nested inside the Following tab so the bottom
  /// navigation bar stays visible.
  static const String notificationHistory = '/following/notifications';

  /// `/article/:id` for a given story.
  static String articleFor(String id) => '$article/$id';

  static const String articleName = 'article';
  static const String savedName = 'saved';
}

/// Named route identifiers used by `go_router`.
abstract final class RouteNames {
  static const String forYou = 'for_you';
  static const String news = 'news';
  static const String sports = 'sports';
  static const String following = 'following';
  static const String article = 'article';
  static const String saved = 'saved';
  static const String signIn = 'sign_in';
  static const String notificationHistory = 'following_notifications';
}
