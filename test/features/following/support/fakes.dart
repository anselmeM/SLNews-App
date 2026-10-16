/// Hand-written in-memory fakes for the Following feature tests.
///
/// `test/support/fakes.dart` (owned by the Lead) does not exist yet, so these
/// live inside the feature's own test directory as the contract allows. They
/// implement the frozen repository interfaces directly, which keeps the
/// production controllers (`FollowingController`, `NotificationsController`)
/// under test instead of stubbing them out.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/domain/models/notification_item.dart';
import 'package:slnews_mobile/core/domain/repositories/following_repository.dart';
import 'package:slnews_mobile/core/domain/repositories/notification_repository.dart';
import 'package:slnews_mobile/features/following/presentation/following_page.dart';
import 'package:slnews_mobile/features/following/presentation/notification_history_page.dart';

/// A follow target that is followed state-side, with the catalogue entry the
/// page renders for it.
class _Entry {
  _Entry({required this.catalogue, required this.followed});

  final FollowTarget catalogue;
  bool followed;
}

/// In-memory [FollowingRepository].
class InMemoryFollowingRepository implements FollowingRepository {
  InMemoryFollowingRepository({
    List<FollowTarget> followed = const <FollowTarget>[],
    List<FollowTarget> suggested = const <FollowTarget>[],
  }) {
    for (final FollowTarget target in followed) {
      _entries[target.id] = _Entry(catalogue: target, followed: true);
    }
    for (final FollowTarget target in suggested) {
      _entries[target.id] = _Entry(catalogue: target, followed: false);
    }
  }

  final Map<String, _Entry> _entries = <String, _Entry>{};

  /// Every `follow`/`unfollow`/`toggle` call in order, for assertions.
  final List<FollowTarget> toggleLog = <FollowTarget>[];

  /// Ids present in the catalogue but not currently followed, in catalogue
  /// order — the page renders these under "Most popular with users".
  List<FollowTarget> get suggested => _entries.values
      .where((_Entry entry) => !entry.followed)
      .map((_Entry entry) => entry.catalogue)
      .toList(growable: false);

  @override
  FollowingSnapshot load() {
    final List<FollowTarget> followedTargets = _entries.values
        .where((_Entry entry) => entry.followed)
        .map((_Entry entry) => entry.catalogue)
        .toList(growable: false);
    return FollowingSnapshot(
      followed: followedTargets,
      suggested: suggested,
      sports: _byKind(<FollowKind>{FollowKind.team, FollowKind.league}),
      locations: _byKind(<FollowKind>{FollowKind.location}),
      topics: _byKind(<FollowKind>{FollowKind.topic}),
      publishers: _byKind(<FollowKind>{FollowKind.publisher}),
    );
  }

  @override
  Future<FollowingSnapshot> follow(FollowTarget target) async {
    _entryFor(target).followed = true;
    toggleLog.add(target);
    return load();
  }

  @override
  Future<FollowingSnapshot> unfollow(String targetId) async {
    final _Entry? entry = _entries[targetId];
    if (entry != null) {
      entry.followed = false;
      toggleLog.add(entry.catalogue);
    }
    return load();
  }

  @override
  Future<FollowingSnapshot> toggle(FollowTarget target) async {
    final _Entry entry = _entryFor(target);
    entry.followed = !entry.followed;
    toggleLog.add(target);
    return load();
  }

  @override
  bool isFollowed(String targetId) => _entries[targetId]?.followed ?? false;

  _Entry _entryFor(FollowTarget target) =>
      _entries.putIfAbsent(target.id, () => _Entry(catalogue: target, followed: false));

  List<FollowTarget> _byKind(Set<FollowKind> kinds) => _entries.values
      .where((_Entry entry) => entry.followed && kinds.contains(entry.catalogue.kind))
      .map((_Entry entry) => entry.catalogue)
      .toList(growable: false);
}

/// In-memory [NotificationRepository] that records mutations.
class InMemoryNotificationRepository implements NotificationRepository {
  InMemoryNotificationRepository(this._items);

  List<NotificationItem> _items;

  /// Ids passed to [markRead], in call order.
  final List<String> markReadLog = <String>[];

  /// How many times [markAllRead] was called.
  int markAllReadCalls = 0;

  @override
  List<NotificationItem> get cachedHistory => List<NotificationItem>.unmodifiable(_items);

  @override
  Future<List<NotificationItem>> history({int limit = 30}) async =>
      _items.take(limit).toList(growable: false);

  @override
  Future<void> record(NotificationItem item) async {
    _items = <NotificationItem>[item, ..._items];
  }

  @override
  Future<void> markRead(String id) async {
    markReadLog.add(id);
    _items = _items
        .map((NotificationItem item) => item.id == id ? item.copyWith(isRead: true) : item)
        .toList(growable: false);
  }

  @override
  Future<void> markAllRead() async {
    markAllReadCalls++;
    _items = _items.map((NotificationItem item) => item.copyWith(isRead: true)).toList(growable: false);
  }

  @override
  int get unreadCount => _items.where((NotificationItem item) => !item.isRead).length;
}

/// Seeded catalogue + alert fixtures shared by the widget tests.
class FollowingTestFixture {
  FollowingTestFixture()
    : following = InMemoryFollowingRepository(
        followed: <FollowTarget>[lakers, freetown, politics],
        suggested: <FollowTarget>[koidu, kenema, nationalNews],
      ),
      notifications = InMemoryNotificationRepository(<NotificationItem>[
        NotificationItem(
          id: 'n1',
          title: 'Breaking: Sierra Leone budget passed',
          body: 'Parliament approved the 2027 budget late on Tuesday evening.',
          receivedAt: DateTime.now().subtract(const Duration(minutes: 12)),
          kind: NotificationKind.breaking,
          articleId: 'article-1',
        ),
        NotificationItem(
          id: 'n2',
          title: 'Lakers win again',
          body: 'A 112-104 road win keeps the Lakers top of the Western Conference.',
          receivedAt: DateTime.now().subtract(const Duration(hours: 3)),
          kind: NotificationKind.followedTeam,
        ),
        NotificationItem(
          id: 'n3',
          title: 'Freetown weather alert',
          body: 'Heavy rain expected across the Western Area this weekend.',
          receivedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
          kind: NotificationKind.system,
          isRead: true,
        ),
      ]);

  final InMemoryFollowingRepository following;
  final InMemoryNotificationRepository notifications;

  /// Followed team crest (no image → initials circle).
  static const FollowTarget lakers = FollowTarget(
    id: 'team:lal',
    kind: FollowKind.team,
    label: 'Los Angeles Lakers',
    subtitle: 'Basketball · NBA',
  );

  /// Followed city.
  static const FollowTarget freetown = FollowTarget(
    id: 'city:freetown',
    kind: FollowKind.location,
    label: 'Freetown',
    subtitle: 'Western Area',
  );

  /// Followed topic.
  static const FollowTarget politics = FollowTarget(
    id: 'topic:politics',
    kind: FollowKind.topic,
    label: 'Politics',
  );

  /// Popular location suggestion that is not followed yet.
  static const FollowTarget koidu = FollowTarget(
    id: 'city:koidu',
    kind: FollowKind.location,
    label: 'Koidu',
    subtitle: 'Kono District',
    isPopular: true,
  );

  /// Second popular location suggestion.
  static const FollowTarget kenema = FollowTarget(
    id: 'city:kenema',
    kind: FollowKind.location,
    label: 'Kenema',
    subtitle: 'Eastern Province',
    isPopular: true,
  );

  /// Popular publisher suggestion — must not appear in the locations group.
  static const FollowTarget nationalNews = FollowTarget(
    id: 'publisher:national',
    kind: FollowKind.publisher,
    label: 'National News',
    isPopular: true,
  );
}

/// A [GoRouter] that serves the Following tab and its nested history route, so
/// the pages' `context.go`/`context.push`/`context.pop` calls run against a real
/// router instead of throwing "No GoRouter found in context".
///
/// Because the history page is a *nested* route, it can only be reached through
/// the `/following` branch (which also mounts [FollowingPage]); tests that only
/// want the history screen navigate to `/following/notifications` explicitly.
GoRouter buildFollowingTestRouter({String initialLocation = '/following'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/following',
        builder: (BuildContext context, GoRouterState state) => const FollowingPage(),
        routes: <RouteBase>[
          GoRoute(
            path: 'notifications',
            builder: (BuildContext context, GoRouterState state) => const NotificationHistoryPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/article/:id',
        builder: (BuildContext context, GoRouterState state) =>
            ArticleStub(articleId: state.pathParameters['id'] ?? ''),
      ),
    ],
  );
}

/// Minimal stand-in for the reader route, so a push can be observed.
class ArticleStub extends StatelessWidget {
  const ArticleStub({super.key, required this.articleId});

  final String articleId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('article-stub:$articleId')));
  }
}
