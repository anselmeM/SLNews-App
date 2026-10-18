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

  /// Full-screen video reel, pushed above the shell like the reader.
  static const String video = '/video';

  /// Identity surface, pushed above the shell so it covers the navigation bar.
  static const String signIn = '/sign_in';

  /// Reader settings, pushed above the shell like the reference screen (which
  /// hides the bottom navigation).
  static const String settings = '/settings';

  /// Notification history, nested inside the Following tab so the bottom
  /// navigation bar stays visible.
  static const String notificationHistory = '/following/notifications';

  /// `/article/:id` for a given story.
  static String articleFor(String id) => '$article/$id';

  /// `/video/:id` for the reel, starting on that moment.
  static String videoFor(String id) => '$video/${Uri.encodeComponent(id)}';

  static const String articleName = 'article';
  static const String savedName = 'saved';
  static const String settingsName = 'settings';
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
  static const String settings = 'settings';
  static const String notificationHistory = 'following_notifications';
  static const String video = 'video';
}
