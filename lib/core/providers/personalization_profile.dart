import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/preferences_store.dart';
import '../domain/auth/account_scope.dart';
import '../domain/models/article.dart';
import '../domain/models/personalization_profile.dart';
import '../utils/app_log.dart';
import 'app_providers.dart';
import 'auth_providers.dart';

/// Versioned preference key for the on-device personalization profile.
const String personalizationProfileKey = 'personalization.profile.v1';

/// Account-scoped key. Engagement signals and reading positions must never
/// carry across identities on a shared device.
String personalizationProfileKeyFor(String accountKey) =>
    '$personalizationProfileKey.$accountKey';

/// Set after an explicit reset so a failed legacy cleanup cannot resurrect the
/// pre-reset anonymous document.
const String personalizationProfileResetKey = 'personalization.profileReset.v1';

String personalizationProfileResetKeyFor(String accountKey) =>
    '$personalizationProfileResetKey.$accountKey';

/// Local, private engagement profile used by For You.
///
/// It records a small event log and reading positions. There is intentionally no
/// backend call here; a reset in Settings removes the whole document.
final NotifierProvider<PersonalizationProfileController, PersonalizationProfile>
personalizationProfileProvider =
    NotifierProvider<PersonalizationProfileController, PersonalizationProfile>(
      PersonalizationProfileController.new,
      name: 'personalizationProfile',
    );

class PersonalizationProfileController
    extends Notifier<PersonalizationProfile> {
  Future<void> _writeBarrier = Future<void>.value();

  @override
  PersonalizationProfile build() {
    final String accountKey = ref.watch(activeAccountKeyProvider);
    return _read(accountKey);
  }

  PersonalizationProfile _read(String accountKey) {
    try {
      final PreferencesStore? preferences = _preferences();
      String? raw = preferences?.string(
        personalizationProfileKeyFor(accountKey),
      );
      // Only the old anonymous document may migrate; never adopt another
      // account's profile into a newly signed-in account. A reset marker keeps
      // a partially failed legacy cleanup from restoring the profile.
      if (raw == null && accountKey == anonymousAccountId) {
        final bool wasReset =
            preferences?.boolean(
              personalizationProfileResetKeyFor(accountKey),
            ) ==
            true;
        if (!wasReset) raw = preferences?.string(personalizationProfileKey);
      }
      if (raw == null || raw.isEmpty) return const PersonalizationProfile();
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return const PersonalizationProfile();
      return PersonalizationProfile.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (error) {
      AppLog.debug('PersonalizationProfile: unreadable profile: $error');
      return const PersonalizationProfile();
    }
  }

  /// A lightweight open signal; reading completion is recorded separately.
  void recordOpen(Article article, {String? accountKey}) {
    _append(
      EngagementEvent(
        articleId: article.id,
        topicId: article.categoryId,
        publisherId: article.publisher.id,
        kind: EngagementKind.open,
        at: DateTime.now(),
        weight: 0.25,
        tags: _normalizedTags(article),
      ),
      accountKey: accountKey,
    );
  }

  /// Records dwell time and final reading progress when the reader leaves.
  void recordRead(
    Article article, {
    required Duration dwell,
    required double progress,
    String? accountKey,
  }) {
    final String owner = accountKey ?? _accountKey();
    final bool sameAccount = owner == _accountKey();
    final PersonalizationProfile base = sameAccount ? state : _read(owner);
    final DateTime now = DateTime.now();
    final double boundedProgress = progress.clamp(0.0, 1.0).toDouble();
    final bool shortAndShallow = dwell.inSeconds < 8 && boundedProgress < 0.15;
    final bool deepRead = dwell.inSeconds >= 20 && boundedProgress >= 0.5;
    final EngagementKind kind = shortAndShallow
        ? EngagementKind.skip
        : EngagementKind.read;
    final double weight = shortAndShallow
        ? -2
        : deepRead
        ? 2.5
        : 1;

    final Map<String, ReadingProgressEntry> nextProgress =
        <String, ReadingProgressEntry>{...base.progress};
    if (boundedProgress >= 0.05) {
      final ReadingProgressEntry? previous = nextProgress[article.id];
      final double maxProgress = previous == null
          ? boundedProgress
          : (boundedProgress > previous.progress
                ? boundedProgress
                : previous.progress);
      nextProgress[article.id] = ReadingProgressEntry(
        articleId: article.id,
        progress: maxProgress,
        lastReadAt: now,
      );
      _trimProgress(nextProgress);
    }

    _append(
      EngagementEvent(
        articleId: article.id,
        topicId: article.categoryId,
        publisherId: article.publisher.id,
        kind: kind,
        at: now,
        weight: weight,
        progress: boundedProgress,
        dwellSeconds: dwell.inSeconds,
        tags: _normalizedTags(article),
      ),
      progress: nextProgress,
      accountKey: owner,
    );
  }

  void recordSave(Article article, {String? accountKey}) {
    _append(
      EngagementEvent(
        articleId: article.id,
        topicId: article.categoryId,
        publisherId: article.publisher.id,
        kind: EngagementKind.save,
        at: DateTime.now(),
        weight: 4,
        tags: _normalizedTags(article),
      ),
      accountKey: accountKey,
    );
  }

  void recordLike(Article article, {String? accountKey}) {
    _append(
      EngagementEvent(
        articleId: article.id,
        topicId: article.categoryId,
        publisherId: article.publisher.id,
        kind: EngagementKind.like,
        at: DateTime.now(),
        weight: 3,
        tags: _normalizedTags(article),
      ),
      accountKey: accountKey,
    );
  }

  /// Explicit "Show less like this": hide the story from For You and lower the
  /// topic/publisher affinity.
  void recordDismiss(Article article, {String? accountKey}) {
    final String owner = accountKey ?? _accountKey();
    final PersonalizationProfile base = owner == _accountKey()
        ? state
        : _read(owner);
    final Map<String, ReadingProgressEntry> nextProgress =
        <String, ReadingProgressEntry>{...base.progress}..remove(article.id);
    _append(
      EngagementEvent(
        articleId: article.id,
        topicId: article.categoryId,
        publisherId: article.publisher.id,
        kind: EngagementKind.dismiss,
        at: DateTime.now(),
        weight: -5,
        tags: _normalizedTags(article),
      ),
      progress: nextProgress,
      accountKey: owner,
    );
  }

  Future<void> clear() async {
    state = const PersonalizationProfile();
    final PreferencesStore? preferences = _preferences();
    if (preferences == null) return;
    final String accountKey = _accountKey();
    final Future<void> removal = _writeBarrier.then((_) async {
      try {
        await preferences.putBool(
          personalizationProfileResetKeyFor(accountKey),
          true,
        );
      } catch (error) {
        AppLog.debug('PersonalizationProfile: reset marker failed: $error');
      }
      final String scopedKey = personalizationProfileKeyFor(accountKey);
      bool scopedRemoved = false;
      try {
        await preferences.remove(scopedKey);
        scopedRemoved = true;
      } catch (error) {
        AppLog.debug('PersonalizationProfile: clear failed: $error');
      }
      if (!scopedRemoved) {
        try {
          await preferences.putString(
            scopedKey,
            jsonEncode(const PersonalizationProfile().toJson()),
          );
        } catch (error) {
          AppLog.debug('PersonalizationProfile: empty reset failed: $error');
        }
      }
      if (accountKey == anonymousAccountId) {
        try {
          await preferences.remove(personalizationProfileKey);
        } catch (error) {
          AppLog.debug('PersonalizationProfile: legacy clear failed: $error');
        }
      }
    });
    _writeBarrier = removal.catchError((Object _) {});
    await removal;
  }

  /// Awaits all queued local persistence; used by tests and diagnostics.
  Future<void> flushPersistence() => _writeBarrier;

  void _append(
    EngagementEvent event, {
    Map<String, ReadingProgressEntry>? progress,
    String? accountKey,
  }) {
    final String owner = accountKey ?? _accountKey();
    if (owner != _accountKey()) {
      // The account switched while the interaction was in flight. Persist to
      // the owner without contaminating the new account's in-memory profile.
      _appendForAccount(owner, event, progress);
      return;
    }
    final List<EngagementEvent> events = <EngagementEvent>[
      event,
      ...state.events,
    ];
    if (events.length > PersonalizationProfile.maxEvents) {
      events.removeRange(PersonalizationProfile.maxEvents, events.length);
    }
    state = PersonalizationProfile(
      events: events,
      progress: progress ?? state.progress,
    );
    _persist(owner);
  }

  void _appendForAccount(
    String accountKey,
    EngagementEvent event,
    Map<String, ReadingProgressEntry>? progress,
  ) {
    final Future<void> write = _writeBarrier.then((_) async {
      final PreferencesStore? preferences = _preferences();
      if (preferences == null) return;
      final PersonalizationProfile existing = _read(accountKey);
      final List<EngagementEvent> events = <EngagementEvent>[
        event,
        ...existing.events,
      ];
      if (events.length > PersonalizationProfile.maxEvents) {
        events.removeRange(PersonalizationProfile.maxEvents, events.length);
      }
      final PersonalizationProfile next = PersonalizationProfile(
        events: events,
        progress: progress ?? existing.progress,
      );
      await preferences.putString(
        personalizationProfileKeyFor(accountKey),
        jsonEncode(next.toJson()),
      );
    });
    _writeBarrier = write.catchError((Object error) {
      AppLog.debug('PersonalizationProfile: late event failed: $error');
    });
  }

  static void _trimProgress(Map<String, ReadingProgressEntry> progress) {
    if (progress.length <= PersonalizationProfile.maxProgressEntries) return;
    final List<ReadingProgressEntry> entries = progress.values.toList()
      ..sort(
        (ReadingProgressEntry a, ReadingProgressEntry b) =>
            a.lastReadAt.compareTo(b.lastReadAt),
      );
    final int remove =
        progress.length - PersonalizationProfile.maxProgressEntries;
    for (final ReadingProgressEntry entry in entries.take(remove)) {
      progress.remove(entry.articleId);
    }
  }

  void _persist(String accountKey) {
    final PreferencesStore? preferences = _preferences();
    if (preferences == null) return;
    final String payload = jsonEncode(state.toJson());
    final Future<void> write = _writeBarrier.then(
      (_) => preferences.putString(
        personalizationProfileKeyFor(accountKey),
        payload,
      ),
    );
    _writeBarrier = write.catchError((Object error) {
      AppLog.debug('PersonalizationProfile: persistence failed: $error');
    });
  }

  static List<String> _normalizedTags(Article article) => <String>[
    for (final String tag in article.tags.take(5))
      if (tag.trim().isNotEmpty) tag.trim().toLowerCase(),
  ];

  PreferencesStore? _preferences() {
    try {
      return ref.read(preferencesStoreProvider);
    } catch (_) {
      return null;
    }
  }

  String _accountKey() {
    try {
      return ref.read(activeAccountKeyProvider);
    } catch (_) {
      return anonymousAccountId;
    }
  }
}

/// One unfinished article resolved against the article cache.
class ContinueReadingEntry {
  const ContinueReadingEntry({
    required this.article,
    required this.progress,
    required this.lastReadAt,
  });

  final Article article;
  final double progress;
  final DateTime lastReadAt;
}

/// Resolves the profile's unfinished positions to articles for the rail.
final FutureProvider<List<ContinueReadingEntry>> continueReadingProvider =
    FutureProvider<List<ContinueReadingEntry>>((Ref ref) async {
      final PersonalizationProfile profile = ref.watch(
        personalizationProfileProvider,
      );
      final List<ReadingProgressEntry> candidates = profile.continueReading();
      if (candidates.isEmpty) return const <ContinueReadingEntry>[];

      final List<ContinueReadingEntry> resolved = <ContinueReadingEntry>[];
      for (final ReadingProgressEntry candidate in candidates) {
        try {
          final Article? article = await ref
              .read(articleRepositoryProvider)
              .byId(candidate.articleId);
          if (article == null) continue;
          if (profile.dismissedArticleIds().contains(article.id)) continue;
          resolved.add(
            ContinueReadingEntry(
              article: article,
              progress: candidate.progress,
              lastReadAt: candidate.lastReadAt,
            ),
          );
        } catch (_) {
          // A missing article just drops out of the small rail.
        }
      }
      return List<ContinueReadingEntry>.unmodifiable(resolved);
    }, name: 'continueReading');
