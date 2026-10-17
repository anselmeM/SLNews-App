/// Reader-owned state: bookmarks, likes and preferences.
///
/// Everything here is synchronous to read because it is hydrated from local
/// storage during start-up; writes are asynchronous and offline-safe.
abstract interface class UserStateRepository {
  Set<String> get bookmarkedIds;

  Set<String> get likedIds;

  bool isBookmarked(String articleId);

  bool isLiked(String articleId);

  Future<void> toggleBookmark(String articleId);

  Future<void> toggleLike(String articleId);

  /// `system`, `light` or `dark`.
  String get themeMode;

  Future<void> setThemeMode(String mode);

  /// User text scale multiplier applied on top of the system setting.
  double get textScale;

  Future<void> setTextScale(double scale);

  /// Followed location driving the local feed and weather header.
  String get activeLocationId;

  Future<void> setActiveLocationId(String locationId);

  bool get breakingNewsAlertsEnabled;

  Future<void> setBreakingNewsAlertsEnabled(bool enabled);

  /// "Editor's picks" notifications.
  bool get editorsPicksEnabled;

  Future<void> setEditorsPicksEnabled(bool enabled);

  /// "Interactive content" notifications.
  bool get interactiveContentEnabled;

  Future<void> setInteractiveContentEnabled(bool enabled);

  /// Alerts for followed teams, leagues and scores.
  bool get sportsAlertsEnabled;

  Future<void> setSportsAlertsEnabled(bool enabled);

  /// Whether the feeds show the weather row.
  bool get weatherForecastEnabled;

  Future<void> setWeatherForecastEnabled(bool enabled);
}
