import 'package:hive/hive.dart';
import 'package:slnews_mobile/core/utils/app_log.dart';

/// Key/value storage for reader preferences.
///
/// Reads are synchronous so view models can render the first frame without a
/// spinner, and every implementation returns safe defaults before [init] has
/// resolved instead of throwing: start-up ordering between the app shell and
/// the data layer is not guaranteed.
abstract interface class PreferencesStore {
  /// Opens or migrates the backing store. Safe to call more than once.
  Future<void> init();

  /// Members of the set stored at [key]; empty when absent or of another type.
  ///
  /// Always a fresh, mutable set, so callers can stage an update and write it
  /// back with [putStringSet].
  Set<String> stringSet(String key);

  /// Replaces the set at [key]. Stored as a list of primitives.
  Future<void> putStringSet(String key, Set<String> values);

  /// String at [key], or `null` when absent or of another type.
  String? string(String key);

  Future<void> putString(String key, String value);

  /// Boolean at [key], or `null` when absent or of another type.
  bool? boolean(String key);

  Future<void> putBool(String key, bool value);

  /// Double at [key], or `null` when absent or of another type.
  double? number(String key);

  Future<void> putNumber(String key, double value);

  /// Forgets [key]; a no-op when it is absent.
  Future<void> remove(String key);
}

/// Process-lifetime store used by tests and as a fallback when Hive is
/// unavailable.
class InMemoryPreferencesStore implements PreferencesStore {
  /// Creates a store, optionally pre-populated with [seed] values.
  InMemoryPreferencesStore([Map<String, Object?>? seed])
    : _values = <String, Object?>{...?seed};

  final Map<String, Object?> _values;

  @override
  Future<void> init() async {}

  @override
  Set<String> stringSet(String key) {
    final Object? raw = _values[key];
    if (raw is Iterable) return raw.whereType<String>().toSet();
    // Mutable on purpose: callers stage updates on the returned set.
    return <String>{};
  }

  @override
  Future<void> putStringSet(String key, Set<String> values) async {
    _values[key] = values.toList(growable: false);
  }

  @override
  String? string(String key) {
    final Object? raw = _values[key];
    return raw is String ? raw : null;
  }

  @override
  Future<void> putString(String key, String value) async {
    _values[key] = value;
  }

  @override
  bool? boolean(String key) {
    final Object? raw = _values[key];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    return null;
  }

  @override
  Future<void> putBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  double? number(String key) {
    final Object? raw = _values[key];
    return raw is num ? raw.toDouble() : null;
  }

  @override
  Future<void> putNumber(String key, double value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

/// Hive-backed store holding only primitives (`String`, `bool`, `double` and
/// `List<String>`).
///
/// Deliberately adapter-free: preferences are read on the very first frame, so
/// the box must open even after a model change. Reads never touch the disk,
/// which is why [init] is the only asynchronous step.
class HivePreferencesStore implements PreferencesStore {
  /// Creates a store bound to [boxName]; call [init] (or [open]) before use.
  HivePreferencesStore({String boxName = 'slnews_prefs'}) : _name = boxName;

  /// Opens the box and returns a ready store.
  static Future<HivePreferencesStore> open({
    String boxName = 'slnews_prefs',
  }) async {
    final HivePreferencesStore store = HivePreferencesStore(boxName: boxName);
    await store.init();
    return store;
  }

  final String _name;
  Box<dynamic>? _box;

  @override
  Future<void> init() async {
    if (_openBox != null) return;
    try {
      _box = Hive.isBoxOpen(_name)
          ? Hive.box<dynamic>(_name)
          : await Hive.openBox<dynamic>(_name);
    } catch (error) {
      // Hive may not be initialised yet (no Flutter binding, no path); reads
      // then degrade to defaults instead of failing the first frame.
      AppLog.debug('HivePreferencesStore: could not open "$_name": $error');
      _box = null;
    }
  }

  Box<dynamic>? get _openBox => (_box?.isOpen ?? false) ? _box : null;

  @override
  Set<String> stringSet(String key) {
    final Object? raw = _openBox?.get(key);
    if (raw is Iterable) return raw.whereType<String>().toSet();
    // Mutable on purpose: callers stage updates on the returned set.
    return <String>{};
  }

  @override
  Future<void> putStringSet(String key, Set<String> values) async {
    await _openBox?.put(key, values.toList(growable: false));
  }

  @override
  String? string(String key) {
    final Object? raw = _openBox?.get(key);
    return raw is String ? raw : null;
  }

  @override
  Future<void> putString(String key, String value) async {
    await _openBox?.put(key, value);
  }

  @override
  bool? boolean(String key) {
    final Object? raw = _openBox?.get(key);
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    return null;
  }

  @override
  Future<void> putBool(String key, bool value) async {
    await _openBox?.put(key, value);
  }

  @override
  double? number(String key) {
    final Object? raw = _openBox?.get(key);
    return raw is num ? raw.toDouble() : null;
  }

  @override
  Future<void> putNumber(String key, double value) async {
    await _openBox?.put(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _openBox?.delete(key);
  }
}
