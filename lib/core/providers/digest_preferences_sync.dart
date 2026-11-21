import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/preferences_store.dart';
import '../data/sources/notification_preferences_source.dart';
import '../domain/auth/auth_repository.dart';
import '../domain/models/digest_preferences.dart';
import '../domain/repositories/user_state_repository.dart';
import '../utils/app_log.dart';
import 'app_providers.dart';
import 'auth_providers.dart';

/// One sync helper for the app; its own provider keeps queued work alive
/// across SettingsController rebuilds (e.g. an account switch).
final Provider<DigestPreferencesSync> digestPreferencesSyncProvider =
    Provider<DigestPreferencesSync>(
      (Ref ref) => DigestPreferencesSync(ref),
      name: 'digestPreferencesSync',
    );

/// Owns the digest-preference lifecycle: account-scoped local cache, pending
/// patches, a serialized PUT queue, retries and server hydration.
///
/// Kept out of `SettingsController` so that class stays about settings state and
/// this one stays about persistence and ordering.
class DigestPreferencesSync {
  DigestPreferencesSync(this._ref);

  final Ref _ref;

  /// Cache namespace for a reader who is not signed in.
  static const String signedOutAccountId = 'local';

  // Device-wide keys used before preferences were account-scoped. They are
  // migrated once and then removed.
  static const String _legacyEnabledKey = 'settings.digestEnabled';
  static const String _legacyQuietStartKey = 'settings.quietStartMinutes';
  static const String _legacyQuietEndKey = 'settings.quietEndMinutes';

  /// Serializes saves so an older PUT cannot land after a newer one.
  Future<void> _saveQueue = Future<void>.value();

  /// Bumped for every patch; a response may only clear the pending document if
  /// no newer change has been queued meanwhile.
  int _patchGeneration = 0;

  UserStateRepository get _repository => _ref.read(userStateProvider);

  DigestPreferencesGateway? get _gateway =>
      _ref.read(notificationPreferencesSourceProvider);

  AuthState? get _auth {
    try {
      return _ref.read(authControllerProvider);
    } catch (_) {
      return null;
    }
  }

  bool get isSignedIn => _auth?.isSignedIn ?? false;

  String accountId() => _auth?.user?.id ?? signedOutAccountId;

  /// The account's local document, or defaults when absent/corrupt.
  ///
  /// Older builds stored digest settings under device-wide keys; if no scoped
  /// document exists yet those are migrated once into this account.
  DigestPreferences read(String account) {
    final String? raw = _repository.digestPreferencesFor(account);
    if (raw == null || raw.isEmpty) {
      final DigestPreferences? legacy = _migrateLegacy(account);
      if (legacy != null) return legacy;
    }
    final Map<String, dynamic>? decoded = _decodeMap(raw, label: 'cache');
    return decoded == null
        ? const DigestPreferences()
        : DigestPreferences.fromJson(decoded);
  }

  DigestPreferences? _migrateLegacy(String account) {
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
    unawaited(writeLocal(account, migrated));
    unawaited(store.remove(_legacyEnabledKey));
    unawaited(store.remove(_legacyQuietStartKey));
    unawaited(store.remove(_legacyQuietEndKey));
    return migrated;
  }

  /// The store is absent in some widget tests that only provide reader state.
  PreferencesStore? _tryPreferencesStore() {
    try {
      return _ref.read(preferencesStoreProvider);
    } catch (_) {
      return null;
    }
  }

  /// Writes the whole document under one key, keeping start/end atomic.
  Future<void> writeLocal(String account, DigestPreferences preferences) =>
      _repository.setDigestPreferencesFor(
        account,
        jsonEncode(preferences.toJson()),
      );

  /// Merges [patch] into the account's pending document and queues its save.
  Future<void> enqueuePatch(String account, Map<String, dynamic> patch) async {
    final Map<String, dynamic> merged = <String, dynamic>{
      ...?_pendingPatch(account),
      ...patch,
    };
    await _repository.setPendingDigestPreferencesFor(
      account,
      jsonEncode(merged),
    );
    final int generation = ++_patchGeneration;
    _saveQueue = _saveQueue.then((_) => _send(account, generation));
  }

  /// Retries the pending patch if the reader is signed in.
  Future<void> retryPending() async {
    if (!isSignedIn) return;
    final String account = accountId();
    if (_repository.pendingDigestPreferencesFor(account) == null) return;
    await _send(account, ++_patchGeneration);
  }

  /// Pushes pending work, then hydrates from the server.
  ///
  /// Returns the server copy only when it is still current; null means the
  /// caller should keep its local state.
  Future<DigestPreferences?> hydrate() async {
    if (!isSignedIn) return null;
    final String account = accountId();
    await _adoptAnonymousPending(account);
    if (_gateway == null) return null;
    if (!await _pushPendingBeforeHydrate(account)) return null;

    final DigestPreferences? server = await _fetchCurrentServer(account);
    if (server != null) await writeLocal(account, server);
    return server;
  }

  /// Returns false when a pending patch could not be delivered.
  Future<bool> _pushPendingBeforeHydrate(String account) async {
    if (_repository.pendingDigestPreferencesFor(account) == null) return true;
    await retryPending();
    await _saveQueue;
    return _repository.pendingDigestPreferencesFor(account) == null;
  }

  Future<DigestPreferences?> _fetchCurrentServer(String account) async {
    final int generation = _patchGeneration;
    try {
      final DigestPreferences? server = await _gateway?.fetch();
      if (server == null) return null;
      final bool changedWhileLoading =
          _patchGeneration != generation ||
          _repository.pendingDigestPreferencesFor(account) != null;
      return changedWhileLoading ? null : server;
    } catch (error) {
      AppLog.debug('DigestPreferencesSync: load failed: $error');
      return null;
    }
  }

  /// Waits for queued PUTs; used by tests.
  Future<void> flushSaves() => _saveQueue;

  Future<void> _send(String account, int generation) async {
    final DigestPreferencesGateway? gateway = _gateway;
    // Bind the request to the account that queued it: a session switch between
    // this check and the HTTP call must not send the old account's patch under
    // the new account's token.
    if (gateway == null || !isSignedIn || accountId() != account) return;
    final Map<String, dynamic>? patch = _pendingPatch(account);
    if (patch == null) return;

    final String sent = jsonEncode(patch);
    try {
      await gateway.save(patch);
      await _clearPendingIfCurrent(account, generation, sent);
    } catch (error) {
      AppLog.debug('DigestPreferencesSync: save failed: $error');
    }
  }

  Future<void> _clearPendingIfCurrent(
    String account,
    int generation,
    String sent,
  ) async {
    final bool stillCurrent =
        generation == _patchGeneration &&
        accountId() == account &&
        _repository.pendingDigestPreferencesFor(account) == sent;
    if (stillCurrent) {
      await _repository.setPendingDigestPreferencesFor(account, null);
    }
  }

  /// Moves a change made while signed out onto the account that just signed in.
  Future<void> _adoptAnonymousPending(String account) async {
    if (account == signedOutAccountId) return;
    final Map<String, dynamic>? anonymous = _pendingPatch(signedOutAccountId);
    if (anonymous == null) return;
    final Map<String, dynamic> merged = <String, dynamic>{
      ...anonymous,
      // A patch already queued for this account is newer.
      ...?_pendingPatch(account),
    };
    await _repository.setPendingDigestPreferencesFor(
      account,
      jsonEncode(merged),
    );
    await _repository.setPendingDigestPreferencesFor(signedOutAccountId, null);
  }

  Map<String, dynamic>? _pendingPatch(String account) => _decodeMap(
    _repository.pendingDigestPreferencesFor(account),
    label: 'pending patch',
  );

  /// Tolerant JSON-object decoder shared by the cache and pending patch.
  static Map<String, dynamic>? _decodeMap(
    String? raw, {
    required String label,
  }) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return decoded.map<String, dynamic>(
        (Object? key, Object? value) =>
            MapEntry<String, dynamic>('$key', value),
      );
    } catch (error) {
      AppLog.debug('DigestPreferencesSync: unreadable $label: $error');
      return null;
    }
  }
}
