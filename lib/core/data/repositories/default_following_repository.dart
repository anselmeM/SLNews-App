import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/models/follow_models.dart';
import '../../domain/repositories/following_repository.dart';
import '../local/preferences_store.dart';
import '../seed/seed_data.dart';
import '../seed/seed_loader.dart';

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
  }) : _store = preferences,
       _seeds = seedLoader {
    // Start the catalogue load immediately; load() must not block on it.
    unawaited(_ready);
  }

  /// Followed ids, stored as a `List<String>` of `FollowTarget.id`s.
  static const String followedIdsKey = 'following.ids';

  /// Last known catalogue, stored as JSON so labels survive a cold start.
  static const String catalogueKey = 'following.catalogue';

  static const int _maxSuggestions = 6;

  final PreferencesStore _store;
  final SeedLoader _seeds;

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

  @override
  Future<FollowingSnapshot> follow(FollowTarget target) async {
    await _ready;
    final Set<String> ids = _store.stringSet(followedIdsKey)..add(target.id);
    if (!_catalogue.any((FollowTarget existing) => existing.id == target.id)) {
      // Keep an unseeded target renderable for the rest of the session.
      _catalogue = <FollowTarget>[..._catalogue, target];
    }
    await _store.putStringSet(followedIdsKey, ids);
    return _snapshot();
  }

  @override
  Future<FollowingSnapshot> unfollow(String targetId) async {
    await _ready;
    final Set<String> ids = _store.stringSet(followedIdsKey)..remove(targetId);
    await _store.putStringSet(followedIdsKey, ids);
    return _snapshot();
  }

  @override
  Future<FollowingSnapshot> toggle(FollowTarget target) =>
      isFollowed(target.id) ? unfollow(target.id) : follow(target);

  @override
  bool isFollowed(String targetId) =>
      _store.stringSet(followedIdsKey).contains(targetId);

  Future<void> _hydrate() async {
    _catalogue = _readCachedCatalogue();
    try {
      final SeedData seed = await _seeds.load();
      if (seed.followables.isEmpty) return;
      _catalogue = seed.followables;
      await _store.putString(
        catalogueKey,
        jsonEncode(
          seed.followables
              .map((FollowTarget target) => target.toJson())
              .toList(growable: false),
        ),
      );
    } catch (error) {
      debugPrint('DefaultFollowingRepository: catalogue unavailable: $error');
    }
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
          debugPrint(
            'DefaultFollowingRepository: dropping cached target: $error',
          );
        }
      }
      return targets;
    } on FormatException catch (error) {
      debugPrint(
        'DefaultFollowingRepository: unreadable catalogue cache: $error',
      );
      return const <FollowTarget>[];
    }
  }

  FollowingSnapshot _snapshot() {
    final Set<String> followedIds = _store.stringSet(followedIdsKey);

    final List<FollowTarget> followed = <FollowTarget>[
      for (final FollowTarget target in _catalogue)
        if (followedIds.contains(target.id)) target,
    ];

    final List<FollowTarget> suggested = <FollowTarget>[
      for (final FollowTarget target in _catalogue)
        if (target.isPopular && !followedIds.contains(target.id)) target,
    ];

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

  List<FollowTarget> _byKind(FollowKind kind) => _byKinds(<FollowKind>[kind]);

  List<FollowTarget> _byKinds(List<FollowKind> kinds) => <FollowTarget>[
    for (final FollowTarget target in _catalogue)
      if (kinds.contains(target.kind)) target,
  ];
}
