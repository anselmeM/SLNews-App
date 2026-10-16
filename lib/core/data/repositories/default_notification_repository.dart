import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/notification_item.dart';
import '../../domain/repositories/notification_repository.dart';
import '../local/preferences_store.dart';
import '../seed/seed_data.dart';
import '../seed/seed_loader.dart';

/// Alert history seeded from the bundled bundle and amended at runtime.
///
/// Read state is the only thing persisted, as `notifications.read`: the alert
/// bodies ship with the app, so storing them again would only create a second
/// copy that can drift.
class DefaultNotificationRepository implements NotificationRepository {
  /// Creates a repository over [seedLoader] and [preferences].
  DefaultNotificationRepository({
    required SeedLoader seedLoader,
    required PreferencesStore preferences,
  }) : _seeds = seedLoader,
       _store = preferences {
    unawaited(_ready);
  }

  /// Ids the reader has acknowledged.
  static const String readIdsKey = 'notifications.read';

  /// Upper bound on retained alerts, newest first.
  static const int maxHistory = 50;

  final SeedLoader _seeds;
  final PreferencesStore _store;

  List<NotificationItem> _history = const <NotificationItem>[];

  late final Future<void> _ready = _hydrate();

  /// Resolves once the seeded history has been applied.
  Future<void> ready() => _ready;

  @override
  List<NotificationItem> get cachedHistory =>
      List<NotificationItem>.unmodifiable(_history);

  @override
  Future<List<NotificationItem>> history({int limit = 30}) async {
    await _ready;
    return _history.take(limit).toList(growable: false);
  }

  @override
  Future<void> record(NotificationItem item) async {
    await _ready;
    final List<NotificationItem> next = <NotificationItem>[
      item,
      for (final NotificationItem existing in _history)
        if (existing.id != item.id) existing,
    ];
    _history = next.length > maxHistory ? next.sublist(0, maxHistory) : next;
  }

  @override
  Future<void> markRead(String id) async {
    await _ready;
    await _persistRead(<String>{..._store.stringSet(readIdsKey), id});
    _history = <NotificationItem>[
      for (final NotificationItem item in _history)
        if (item.id == id) item.copyWith(isRead: true) else item,
    ];
  }

  @override
  Future<void> markAllRead() async {
    await _ready;
    await _persistRead(<String>{
      ..._store.stringSet(readIdsKey),
      for (final NotificationItem item in _history) item.id,
    });
    _history = <NotificationItem>[
      for (final NotificationItem item in _history) item.copyWith(isRead: true),
    ];
  }

  @override
  int get unreadCount =>
      _history.where((NotificationItem item) => !item.isRead).length;

  Future<void> _persistRead(Set<String> ids) =>
      _store.putStringSet(readIdsKey, ids);

  Future<void> _hydrate() async {
    try {
      final SeedData seed = await _seeds.load();
      final Set<String> read = _store.stringSet(readIdsKey);
      final List<NotificationItem> history = <NotificationItem>[
        for (final NotificationItem item in seed.notifications)
          if (read.contains(item.id)) item.copyWith(isRead: true) else item,
      ];
      history.sort(
        (NotificationItem a, NotificationItem b) =>
            b.receivedAt.compareTo(a.receivedAt),
      );
      _history = history;
    } catch (error) {
      debugPrint('DefaultNotificationRepository: seed unavailable: $error');
    }
  }
}
