import 'dart:async';
import 'dart:convert';

import '../../domain/auth/account_scope.dart';
import '../../domain/models/follow_models.dart';
import '../../domain/repositories/following_repository.dart';
import '../local/preferences_store.dart';
import '../seed/seed_data.dart';
import '../seed/seed_loader.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

/// Subscriptions backed by a persisted id set and the seeded catalogue.
///
/// [FollowingRepository.load] is synchronous, so the catalogue is cached in
/// [PreferencesStore] as well as read from the seed: on a relaunch the first
/// frame already has labels, and on a first launch [ready] resolves within one
/// asset read.
class DefaultFollowingRepository implements FollowingRepository {
  /// Creates a repository over [preferences] and [seedLoader].
  DefaultFollowingRepository({
    required PreferencesStore preferences,
    required SeedLoader seedLoader,
    String Function()? accountId,
  }) : _store = preferences,
       _seeds = seedLoader,
       _accountId = accountId ?? (() => anonymousAccountId) {
    // Start the catalogue load immediately; load() must not block on it.
    unawaited(_ready);
  }

  /// Legacy followed-id key, migrated into the account-scoped key on read.
  static const String followedIdsKey = 'following.ids';

  /// Last known catalogue, stored as JSON so labels survive a cold start.
  static const String catalogueKey = 'following.catalogue';

  static const int _maxSuggestions = 6;

  final PreferencesStore _store;
  final SeedLoader _seeds;
  final String Function() _accountId;

  List<FollowTarget> _catalogue = const <FollowTarget>[];

  late final Future<void> _ready = _hydrate();

  /// Resolves once the catalogue is available.
  ///
  /// Await it during app start-up to guarantee a populated first frame; without
  /// it, [load] still returns correct follow state, just without catalogue
  /// labels until the seed read finishes.
  Future<void> ready() => _ready;

  @override
  List<FollowTarget> get catalogue => _catalogue;

  @override
  FollowingSnapshot load() {
    unawaited(_ready);
    return _snapshot();
  }

  String get _followedIdsKey =>
      '$followedIdsKey.${localAccountIdFor(_accountId())}';

  /// Reads the active account's followed ids, migrating the global legacy set
  /// once so existing installs keep their subscriptions.
  Set<String> _readFollowedIds() {
    final Set<String> current = _store.stringSet(_followedIdsKey);
    if (current.isNotEmpty) return current;
    final Set<String> legacy = _store.stringSet(followedIdsKey);
    if (legacy.isNotEmpty) {
      unawaited(_store.putStringSet(_followedIdsKey, legacy));
      unawaited(_store.remove(followedIdsKey));
      return legacy;
    }

    final String account = localAccountIdFor(_accountId());
    if (account != anonymousAccountId) {
      final String anonymousKey = '$followedIdsKey.$anonymousAccountId';
      final Set<String> anonymous = _store.stringSet(anonymousKey);
      if (anonymous.isNotEmpty) {
        unawaited(_store.putStringSet(_followedIdsKey, anonymous));
        unawaited(_store.remove(anonymousKey));
        return anonymous;
      }
    }
    return current;
  }

  @override
  Future<FollowingSnapshot> follow(FollowTarget target) async {
    await _ready;
    final Set<String> ids = _readFollowedIds()..add(target.id);
    if (!_catalogue.any((FollowTarget existing) => existing.id == target.id)) {
      // The catalogue is seeded, but the leagues screen follows competitions the
      // seed does not carry (NFL, Formula 1, ...). Keep the target and persist
      // the extended catalogue: follow ids are stored, so without this the
      // subscription would survive a restart while its label and kind did not,
      // and the row would silently disappear from Following.
      _catalogue = <FollowTarget>[..._catalogue, target];
      await _persistCatalogue();
    }
    await _store.putStringSet(_followedIdsKey, ids);
    return _snapshot();
  }

  @override
  Future<FollowingSnapshot> unfollow(String targetId) async {
    await _ready;
    final Set<String> ids = _readFollowedIds()..remove(targetId);
    await _store.putStringSet(_followedIdsKey, ids);
    return _snapshot();
  }

  @override
  Future<FollowingSnapshot> toggle(FollowTarget target) =>
      isFollowed(target.id) ? unfollow(target.id) : follow(target);

  @override
  bool isFollowed(String targetId) => _readFollowedIds().contains(targetId);

  Future<void> _hydrate() async {
    final List<FollowTarget> cached = _readCachedCatalogue();
    _catalogue = cached;
    try {
      final SeedData seed = await _seeds.load();
      if (seed.followables.isEmpty) return;
      _catalogue = _mergeCatalogue(seed.followables, cached);
      await _persistCatalogue();
    } catch (error) {
      AppLog.debug('DefaultFollowingRepository: catalogue unavailable: $error');
    }
  }

  /// The seed catalogue plus any followed target the seed does not carry.
  ///
  /// The leagues screen can follow competitions outside the seed (NFL, Formula 1,
  /// ...). Only ids that are still followed are carried over, so unsubscribing
  /// from one lets it drop out on the next launch instead of accumulating.
  List<FollowTarget> _mergeCatalogue(
    List<FollowTarget> seeded,
    List<FollowTarget> cached,
  ) {
    if (cached.isEmpty) return seeded;
    final Set<String> seededIds = seeded
        .map((FollowTarget target) => target.id)
        .toSet();
    final Set<String> followedIds = _readFollowedIds();
    final List<FollowTarget> extras = <FollowTarget>[
      for (final FollowTarget target in cached)
        if (!seededIds.contains(target.id) && followedIds.contains(target.id))
          target,
    ];
    if (extras.isEmpty) return seeded;
    return <FollowTarget>[...seeded, ...extras];
  }

  /// Writes the current catalogue to the preferences cache.
  Future<void> _persistCatalogue() async {
    if (_catalogue.isEmpty) return;
    await _store.putString(
      catalogueKey,
      jsonEncode(
        _catalogue
            .map((FollowTarget target) => target.toJson())
            .toList(growable: false),
      ),
    );
  }

  List<FollowTarget> _readCachedCatalogue() {
    final String? raw = _store.string(catalogueKey);
    if (raw == null || raw.isEmpty) return const <FollowTarget>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const <FollowTarget>[];
      final List<FollowTarget> targets = <FollowTarget>[];
      for (final Object? entry in decoded) {
        if (entry is! Map) continue;
        try {
          targets.add(FollowTarget.fromJson(entry.cast<String, dynamic>()));
        } catch (error) {
          AppLog.debug(
            'DefaultFollowingRepository: dropping cached target: $error',
          );
        }
      }
      return targets;
    } on FormatException catch (error) {
      AppLog.debug(
        'DefaultFollowingRepository: unreadable catalogue cache: $error',
      );
      return const <FollowTarget>[];
    }
  }

  FollowingSnapshot _snapshot() {
    final Set<String> followedIds = _readFollowedIds();

    final List<FollowTarget> followed = <FollowTarget>[
      for (final FollowTarget target in _catalogue)
        if (followedIds.contains(target.id)) target,
    ];

    // Suggestions are the topics the reader does not follow yet, popular first.
    // They used to be only the seeded `isPopular` targets (two topics plus the
    // cities), so following both topics emptied the group — and the cities are
    // no longer a thing the app follows at all.
    final List<FollowTarget> suggested = <FollowTarget>[
      for (final FollowTarget target in _catalogue)
        if (target.kind == FollowKind.topic && !followedIds.contains(target.id))
          target,
    ]..sort(_popularFirst);

    return FollowingSnapshot(
      followed: followed,
      suggested: suggested.length > _maxSuggestions
          ? suggested.sublist(0, _maxSuggestions)
          : suggested,
      sports: _byKinds(const <FollowKind>[FollowKind.team, FollowKind.league]),
      locations: _byKind(FollowKind.location),
      topics: _byKind(FollowKind.topic),
      publishers: _byKind(FollowKind.publisher),
    );
  }

  /// Popular suggestions first, then alphabetical, so the group is stable.
  static int _popularFirst(FollowTarget a, FollowTarget b) {
    if (a.isPopular != b.isPopular) return a.isPopular ? -1 : 1;
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  }

  List<FollowTarget> _byKind(FollowKind kind) => _byKinds(<FollowKind>[kind]);

  List<FollowTarget> _byKinds(List<FollowKind> kinds) => <FollowTarget>[
    for (final FollowTarget target in _catalogue)
      if (kinds.contains(target.kind)) target,
  ];
}
