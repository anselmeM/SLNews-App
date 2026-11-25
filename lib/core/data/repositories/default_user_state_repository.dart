import 'dart:async';

import '../../domain/auth/account_scope.dart';
import '../../domain/repositories/user_state_repository.dart';
import '../local/preferences_store.dart';

/// Bookmarks, likes and settings persisted through [PreferencesStore].
///
/// Reads go straight to the store on every access rather than caching: the
/// store is synchronous, and a single source of truth means a write from one
/// view model is immediately visible to every other reader.
class DefaultUserStateRepository implements UserStateRepository {
  /// Creates a repository over [preferences].
  ///
  /// [accountId] is read on every access so the same repository follows a
  /// sign-in, sign-out or account switch without being rebuilt.
  DefaultUserStateRepository({
    required PreferencesStore preferences,
    String Function()? accountId,
  }) : _store = preferences,
       _accountId = accountId ?? (() => anonymousAccountId);

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
  static const String personalizeFeedKey = 'settings.personalizeFeed';
  static const String onboardingKey = 'settings.onboardingCompleted';

  /// Digest preferences are one device-local document; they are not synced.
  static const String digestPreferencesKey = 'settings.digestPreferences';

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
  static const bool defaultPersonalizeFeed = true;
  static const bool defaultOnboardingCompleted = false;

  final PreferencesStore _store;
  final String Function() _accountId;

  @override
  Set<String> get bookmarkedIds =>
      _readerIds(bookmarksKey, legacyKey: bookmarksKey);

  @override
  Set<String> get likedIds => _readerIds(likesKey, legacyKey: likesKey);

  @override
  bool isBookmarked(String articleId) => bookmarkedIds.contains(articleId);

  @override
  bool isLiked(String articleId) => likedIds.contains(articleId);

  @override
  Future<void> toggleBookmark(String articleId) =>
      _toggleReaderId(bookmarksKey, articleId);

  @override
  Future<void> toggleLike(String articleId) =>
      _toggleReaderId(likesKey, articleId);

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
  bool get onboardingCompleted =>
      _store.boolean(onboardingKey) ?? defaultOnboardingCompleted;

  @override
  Future<void> setOnboardingCompleted(bool completed) =>
      _store.putBool(onboardingKey, completed);

  @override
  bool get weatherForecastEnabled =>
      _store.boolean(weatherForecastKey) ?? defaultWeatherForecast;

  String _digestKey(String base, String accountId) =>
      '$base.${accountId.trim().isEmpty ? 'local' : accountId.trim()}';

  @override
  String? digestPreferencesFor(String deviceKey) =>
      _store.string(_digestKey(digestPreferencesKey, deviceKey));

  @override
  Future<void> setDigestPreferencesFor(String deviceKey, String json) =>
      _store.putString(_digestKey(digestPreferencesKey, deviceKey), json);

  @override
  Future<void> setWeatherForecastEnabled(bool enabled) =>
      _store.putBool(weatherForecastKey, enabled);

  @override
  bool get personalizeFeed =>
      _store.boolean(personalizeFeedKey) ?? defaultPersonalizeFeed;

  @override
  Future<void> setPersonalizeFeed(bool enabled) =>
      _store.putBool(personalizeFeedKey, enabled);

  /// Account-scoped key for reader-owned collections.
  String _readerKey(String base) => '$base.${localAccountIdFor(_accountId())}';

  /// Reads the current account's set, migrating pre-account-scope data once.
  Set<String> _readerIds(String base, {required String legacyKey}) {
    final String scopedKey = _readerKey(base);
    final Set<String> current = _store.stringSet(scopedKey);
    if (current.isNotEmpty) return current;

    final Set<String> legacy = _store.stringSet(legacyKey);
    if (legacy.isNotEmpty) {
      // The global key belonged to whoever was active before this migration.
      unawaited(_store.putStringSet(scopedKey, legacy));
      unawaited(_store.remove(legacyKey));
      return legacy;
    }

    // A reader who saved something before signing in gets those local saves
    // adopted once by the first account they sign into. Signing out never
    // copies account data back into the anonymous namespace.
    final String account = localAccountIdFor(_accountId());
    if (account != anonymousAccountId) {
      final String anonymousKey = '$base.$anonymousAccountId';
      final Set<String> anonymous = _store.stringSet(anonymousKey);
      if (anonymous.isNotEmpty) {
        unawaited(_store.putStringSet(scopedKey, anonymous));
        unawaited(_store.remove(anonymousKey));
        return anonymous;
      }
    }
    return current;
  }

  Future<void> _toggleReaderId(String base, String id) async {
    final Set<String> values = _readerIds(base, legacyKey: base);
    if (!values.remove(id)) values.add(id);
    await _store.putStringSet(_readerKey(base), values);
  }
}
