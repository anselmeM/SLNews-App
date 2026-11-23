import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/preferences_store.dart';
import '../domain/models/digest_preferences.dart';
import '../domain/repositories/user_state_repository.dart';
import 'app_providers.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

/// Device-local digest choices.
///
/// Signing in must not move these preferences between accounts or devices: the
/// account sync contract covers saved stories, likes and follows only.
final Provider<DigestPreferencesStore> digestPreferencesStoreProvider =
    Provider<DigestPreferencesStore>(
      (Ref ref) => DigestPreferencesStore(ref),
      name: 'digestPreferencesStore',
    );

class DigestPreferencesStore {
  DigestPreferencesStore(this._ref);

  final Ref _ref;

  /// Device-wide namespace. Account ids are deliberately ignored.
  static const String deviceKey = 'device';

  /// The old signed-out namespace; migrated into [deviceKey] on first read.
  static const String legacyLocalKey = 'local';

  // Device-wide keys used by builds before digest preferences were namespaced.
  static const String _legacyEnabledKey = 'settings.digestEnabled';
  static const String _legacyQuietStartKey = 'settings.quietStartMinutes';
  static const String _legacyQuietEndKey = 'settings.quietEndMinutes';

  UserStateRepository get _repository => _ref.read(userStateProvider);

  /// Reads the one device-wide digest document.
  DigestPreferences read() {
    String? raw = _repository.digestPreferencesFor(deviceKey);
    if (raw == null || raw.isEmpty) {
      raw = _repository.digestPreferencesFor(legacyLocalKey);
      if (raw != null && raw.isNotEmpty) {
        // Keep the signed-out choice that existed before preferences became
        // device-wide. This is a local copy, never a server fetch.
        unawaited(_writeRaw(raw));
        return _decode(raw) ?? const DigestPreferences();
      }
      raw = _migrateLegacyDeviceKeys();
      if (raw != null) unawaited(_writeRaw(raw));
    }
    return raw == null
        ? const DigestPreferences()
        : _decode(raw) ?? const DigestPreferences();
  }

  /// Writes the device-wide digest document.
  Future<void> write(DigestPreferences preferences) =>
      _writeRaw(jsonEncode(preferences.toJson()));

  Future<void> _writeRaw(String json) =>
      _repository.setDigestPreferencesFor(deviceKey, json);

  DigestPreferences? _decode(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return DigestPreferences.fromJson(
        decoded.map<String, dynamic>(
          (Object? key, Object? value) =>
              MapEntry<String, dynamic>('$key', value),
        ),
      );
    } catch (error) {
      AppLog.debug('DigestPreferencesStore: unreadable document: $error');
      return null;
    }
  }

  /// Migrates the pre-namespace device keys once, then removes them.
  String? _migrateLegacyDeviceKeys() {
    final PreferencesStore? store = _tryPreferencesStore();
    if (store == null) return null;
    final bool? enabled = store.boolean(_legacyEnabledKey);
    final int? start = int.tryParse(store.string(_legacyQuietStartKey) ?? '');
    final int? end = int.tryParse(store.string(_legacyQuietEndKey) ?? '');
    if (enabled == null && start == null && end == null) return null;

    final bool hasWindow = start != null && end != null && start != end;
    final DigestPreferences migrated = DigestPreferences(
      digestEnabled: enabled ?? true,
      quietHoursStart: hasWindow ? start : null,
      quietHoursEnd: hasWindow ? end : null,
    );
    unawaited(store.remove(_legacyEnabledKey));
    unawaited(store.remove(_legacyQuietStartKey));
    unawaited(store.remove(_legacyQuietEndKey));
    return jsonEncode(migrated.toJson());
  }

  PreferencesStore? _tryPreferencesStore() {
    try {
      return _ref.read(preferencesStoreProvider);
    } catch (_) {
      return null;
    }
  }
}
