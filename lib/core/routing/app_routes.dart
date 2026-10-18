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

  /// Full Stocks board behind the For You finance card.
  static const String stocks = '/stocks';

  /// Query surface for stories and videos.
  static const String search = '/search';

  /// Pushed "Top stories" section with a photo header.
  static const String topStories = '/top_stories';

  /// Pushed topic/category section (`/section/:id`), same layout as Top stories.
  static const String section = '/section';

  /// Identity surface, pushed above the shell so it covers the navigation bar.
  static const String signIn = '/sign_in';

  /// Reader settings, pushed above the shell like the reference screen (which
  /// hides the bottom navigation).
  static const String settings = '/settings';

  /// Pushed league surface (`/sports/league/:id`): standings, fixtures, stories.
  static const String league = '/sports/league';

  /// Pushed team surface (`/sports/team/:id`): follow, fixtures, stories.
  static const String team = '/sports/team';

  /// Notification history, nested inside the Following tab so the bottom
  /// navigation bar stays visible.
  static const String notificationHistory = '/following/notifications';

  /// `/article/:id` for a given story.
  static String articleFor(String id) => '$article/$id';

  /// `/sports/league/:id` for a competition.
  static String leagueFor(String id) => '$league/${Uri.encodeComponent(id)}';

  /// `/sports/team/:id` for a club or national side.
  static String teamFor(String id) => '$team/${Uri.encodeComponent(id)}';

  /// `/section/:id` for a topic or category.
  static String sectionFor(String id) => '$section/${Uri.encodeComponent(id)}';

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
  static const String articleOriginal = 'article_original';
  static const String saved = 'saved';
  static const String signIn = 'sign_in';
  static const String settings = 'settings';
  static const String stocks = 'stocks';
  static const String search = 'search';
  static const String topStories = 'top_stories';
  static const String section = 'section';
  static const String league = 'league';
  static const String team = 'team';
  static const String notificationHistory = 'following_notifications';
  static const String video = 'video';
}
