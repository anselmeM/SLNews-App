import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/article.dart';
import 'app_providers.dart';

/// Preferences key holding the reader's recently opened story ids, newest first.
const String readingHistoryKey = 'reading_history.v1';

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
    try {
      final String? raw = ref
          .read(preferencesStoreProvider)
          .string(readingHistoryKey);
      if (raw == null || raw.isEmpty) return const <String>[];
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      return <String>[
        for (final Object? entry in decoded)
          if (entry is String && entry.trim().isNotEmpty) entry.trim(),
      ].take(limit).toList(growable: false);
    } catch (_) {
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
    try {
      await ref
          .read(preferencesStoreProvider)
          .putString(readingHistoryKey, jsonEncode(next));
    } catch (_) {
      // History is best-effort; reading must never fail because of it.
    }
  }

  Future<void> clear() async {
    state = const <String>[];
    try {
      await ref.read(preferencesStoreProvider).remove(readingHistoryKey);
    } catch (_) {}
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
