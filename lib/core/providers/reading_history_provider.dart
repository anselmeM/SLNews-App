import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/preferences_store.dart';
import '../domain/auth/account_scope.dart';
import '../domain/models/article.dart';
import '../utils/app_log.dart';
import 'app_providers.dart';
import 'auth_providers.dart';

/// Preferences key prefix holding recently opened story ids.
const String readingHistoryKey = 'reading_history.v1';

/// Account-scoped preference key. Reading history must never leak from one
/// signed-in reader to another on a shared device.
String readingHistoryKeyFor(String accountKey) =>
    '$readingHistoryKey.$accountKey';

/// Local, device-only reading history.
///
/// Deliberately not synced: it is a convenience for "pick up where I left off"
/// on this phone, not part of the account state. Capped so the document stays
/// small and the rail short.
final NotifierProvider<ReadingHistoryController, List<String>>
readingHistoryProvider =
    NotifierProvider<ReadingHistoryController, List<String>>(
      ReadingHistoryController.new,
      name: 'readingHistory',
    );

class ReadingHistoryController extends Notifier<List<String>> {
  static const int limit = 20;

  @override
  List<String> build() {
    final String accountKey = ref.watch(activeAccountKeyProvider);
    return _read(accountKey);
  }

  List<String> _read(String accountKey) {
    try {
      String? raw = ref
          .read(preferencesStoreProvider)
          .string(readingHistoryKeyFor(accountKey));
      // Migrate only the old anonymous document. A signed-in account must not
      // inherit another account's (or the pre-sign-in) browsing history.
      if (raw == null && accountKey == anonymousAccountId) {
        raw = ref.read(preferencesStoreProvider).string(readingHistoryKey);
      }
      if (raw == null || raw.isEmpty) return const <String>[];
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      return <String>[
        for (final Object? entry in decoded)
          if (entry is String && entry.trim().isNotEmpty) entry.trim(),
      ].take(limit).toList(growable: false);
    } catch (error) {
      AppLog.debug('Reading history: unreadable cache: $error');
      return const <String>[];
    }
  }

  Future<void> record(String articleId) async {
    final String id = articleId.trim();
    if (id.isEmpty) return;
    if (state.isNotEmpty && state.first == id) return;
    final List<String> next = <String>[
      id,
      for (final String existing in state)
        if (existing != id) existing,
    ].take(limit).toList(growable: false);
    state = next;
    final String accountKey = ref.read(activeAccountKeyProvider);
    try {
      await ref
          .read(preferencesStoreProvider)
          .putString(readingHistoryKeyFor(accountKey), jsonEncode(next));
    } catch (error) {
      // History is best-effort; reading must never fail because of it.
      AppLog.debug('Reading history: record failed: $error');
    }
  }

  Future<void> clear() async {
    state = const <String>[];
    final String accountKey = ref.read(activeAccountKeyProvider);
    try {
      final PreferencesStore store = ref.read(preferencesStoreProvider);
      await store.remove(readingHistoryKeyFor(accountKey));
      if (accountKey == anonymousAccountId) {
        await store.remove(readingHistoryKey);
      }
    } catch (error) {
      // Clearing is best-effort too.
      AppLog.debug('Reading history: clear failed: $error');
    }
  }
}

/// Recently opened stories, resolved against the article cache.
final FutureProvider<List<Article>> recentlyReadArticlesProvider =
    FutureProvider<List<Article>>((Ref ref) async {
      final List<String> ids = ref.watch(readingHistoryProvider);
      if (ids.isEmpty) return const <Article>[];
      final List<Article> articles = <Article>[];
      for (final String id in ids.take(8)) {
        try {
          final Article? article = await ref
              .read(articleRepositoryProvider)
              .byId(id);
          if (article != null) articles.add(article);
        } catch (_) {
          // A cache miss or an un-overridden repository is not an error here.
        }
      }
      return articles;
    }, name: 'recentlyReadArticles');
