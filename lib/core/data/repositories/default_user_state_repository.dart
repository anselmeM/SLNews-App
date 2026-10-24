import '../../domain/repositories/user_state_repository.dart';
import '../local/preferences_store.dart';

/// Bookmarks, likes and settings persisted through [PreferencesStore].
///
/// Reads go straight to the store on every access rather than caching: the
/// store is synchronous, and a single source of truth means a write from one
/// view model is immediately visible to every other reader.
class DefaultUserStateRepository implements UserStateRepository {
  /// Creates a repository over [preferences].
  DefaultUserStateRepository({required PreferencesStore preferences})
    : _store = preferences;

  /// Preference keys, namespaced so a later migration can find them.
  static const String bookmarksKey = 'user.bookmarks';
  static const String likesKey = 'user.likes';
  static const String themeModeKey = 'settings.themeMode';
  static const String textScaleKey = 'settings.textScale';
  static const String activeLocationKey = 'settings.activeLocation';
  static const String breakingAlertsKey = 'settings.breakingAlerts';
  static const String editorsPicksKey = 'settings.editorsPicks';
  static const String interactiveContentKey = 'settings.interactiveContent';
  static const String sportsAlertsKey = 'settings.sportsAlerts';
  static const String followedTopicAlertsKey = 'settings.followedTopicAlerts';
  static const String weatherForecastKey = 'settings.weatherForecast';

  /// Defaults applied when a key has never been written.
  static const String defaultThemeMode = 'system';
  static const double defaultTextScale = 1.0;
  static const String defaultActiveLocationId = 'city:freetown';
  static const bool defaultBreakingAlerts = true;
  static const bool defaultEditorsPicks = false;
  static const bool defaultInteractiveContent = false;
  static const bool defaultSportsAlerts = true;
  static const bool defaultFollowedTopicAlerts = true;
  static const bool defaultWeatherForecast = true;

  final PreferencesStore _store;

  @override
  Set<String> get bookmarkedIds => _store.stringSet(bookmarksKey);

  @override
  Set<String> get likedIds => _store.stringSet(likesKey);

  @override
  bool isBookmarked(String articleId) =>
      _store.stringSet(bookmarksKey).contains(articleId);

  @override
  bool isLiked(String articleId) =>
      _store.stringSet(likesKey).contains(articleId);

  @override
  Future<void> toggleBookmark(String articleId) =>
      _toggle(bookmarksKey, articleId);

  @override
  Future<void> toggleLike(String articleId) => _toggle(likesKey, articleId);

  @override
  String get themeMode => _store.string(themeModeKey) ?? defaultThemeMode;

  @override
  Future<void> setThemeMode(String mode) =>
      _store.putString(themeModeKey, mode);

  @override
  double get textScale => _store.number(textScaleKey) ?? defaultTextScale;

  @override
  Future<void> setTextScale(double scale) =>
      _store.putNumber(textScaleKey, scale);

  @override
  String get activeLocationId =>
      _store.string(activeLocationKey) ?? defaultActiveLocationId;

  @override
  Future<void> setActiveLocationId(String locationId) =>
      _store.putString(activeLocationKey, locationId);

  @override
  bool get breakingNewsAlertsEnabled =>
      _store.boolean(breakingAlertsKey) ?? defaultBreakingAlerts;

  @override
  Future<void> setBreakingNewsAlertsEnabled(bool enabled) =>
      _store.putBool(breakingAlertsKey, enabled);

  @override
  bool get editorsPicksEnabled =>
      _store.boolean(editorsPicksKey) ?? defaultEditorsPicks;

  @override
  Future<void> setEditorsPicksEnabled(bool enabled) =>
      _store.putBool(editorsPicksKey, enabled);

  @override
  bool get interactiveContentEnabled =>
      _store.boolean(interactiveContentKey) ?? defaultInteractiveContent;

  @override
  Future<void> setInteractiveContentEnabled(bool enabled) =>
      _store.putBool(interactiveContentKey, enabled);

  @override
  bool get sportsAlertsEnabled =>
      _store.boolean(sportsAlertsKey) ?? defaultSportsAlerts;

  @override
  Future<void> setSportsAlertsEnabled(bool enabled) =>
      _store.putBool(sportsAlertsKey, enabled);

  @override
  bool get followedTopicAlertsEnabled =>
      _store.boolean(followedTopicAlertsKey) ?? defaultFollowedTopicAlerts;

  @override
  Future<void> setFollowedTopicAlertsEnabled(bool enabled) =>
      _store.putBool(followedTopicAlertsKey, enabled);

  @override
  bool get weatherForecastEnabled =>
      _store.boolean(weatherForecastKey) ?? defaultWeatherForecast;

  @override
  Future<void> setWeatherForecastEnabled(bool enabled) =>
      _store.putBool(weatherForecastKey, enabled);

  Future<void> _toggle(String key, String id) async {
    // `stringSet` hands back a fresh, growable copy of the stored list.
    final Set<String> values = _store.stringSet(key);
    if (!values.remove(id)) values.add(id);
    await _store.putStringSet(key, values);
  }
}
