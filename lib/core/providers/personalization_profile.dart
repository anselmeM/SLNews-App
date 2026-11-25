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
      String? raw = _preferences()?.string(
        personalizationProfileKeyFor(accountKey),
      );
      // Only the old anonymous document may migrate; never adopt another
      // account's profile into a newly signed-in account.
      if (raw == null && accountKey == anonymousAccountId) {
        raw = _preferences()?.string(personalizationProfileKey);
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
  void recordOpen(Article article) {
    _append(
      EngagementEvent(
        articleId: article.id,
        topicId: article.categoryId,
        publisherId: article.publisher.id,
        kind: EngagementKind.open,
        at: DateTime.now(),
        weight: 0.25,
      ),
    );
  }

  /// Records dwell time and final reading progress when the reader leaves.
  void recordRead(
    Article article, {
    required Duration dwell,
    required double progress,
  }) {
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
        <String, ReadingProgressEntry>{...state.progress};
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
      ),
      progress: nextProgress,
    );
  }

  void recordSave(Article article) {
    _append(
      EngagementEvent(
        articleId: article.id,
        topicId: article.categoryId,
        publisherId: article.publisher.id,
        kind: EngagementKind.save,
        at: DateTime.now(),
        weight: 4,
      ),
    );
  }

  void recordLike(Article article) {
    _append(
      EngagementEvent(
        articleId: article.id,
        topicId: article.categoryId,
        publisherId: article.publisher.id,
        kind: EngagementKind.like,
        at: DateTime.now(),
        weight: 3,
      ),
    );
  }

  /// Explicit "Show less like this": hide the story from For You and lower the
  /// topic/publisher affinity.
  void recordDismiss(Article article) {
    final Map<String, ReadingProgressEntry> nextProgress =
        <String, ReadingProgressEntry>{...state.progress}..remove(article.id);
    _append(
      EngagementEvent(
        articleId: article.id,
        topicId: article.categoryId,
        publisherId: article.publisher.id,
        kind: EngagementKind.dismiss,
        at: DateTime.now(),
        weight: -5,
      ),
      progress: nextProgress,
    );
  }

  Future<void> clear() async {
    state = const PersonalizationProfile();
    final PreferencesStore? preferences = _preferences();
    if (preferences == null) return;
    final String accountKey = _accountKey();
    final Future<void> removal = _writeBarrier.then((_) async {
      try {
        await preferences.remove(personalizationProfileKeyFor(accountKey));
        if (accountKey == anonymousAccountId) {
          await preferences.remove(personalizationProfileKey);
        }
      } catch (error) {
        AppLog.debug('PersonalizationProfile: clear failed: $error');
      }
    });
    _writeBarrier = removal.catchError((Object _) {});
    await removal;
  }

  void _append(
    EngagementEvent event, {
    Map<String, ReadingProgressEntry>? progress,
  }) {
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
    _persist();
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

  void _persist() {
    final PreferencesStore? preferences = _preferences();
    if (preferences == null) return;
    final String accountKey = _accountKey();
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
