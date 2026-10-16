import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../domain/models/article.dart';

/// Disk cache for ingested articles, keyed by feed scope (`all`, `category:top`).
///
/// [read] is synchronous: the first frame renders from whatever was persisted
/// on the previous run instead of waiting on storage.
abstract interface class ArticleCache {
  /// Opens or migrates the backing store. Safe to call more than once.
  Future<void> init();

  /// Persists [articles] under [key] and records the sync timestamp.
  Future<void> write(String key, List<Article> articles);

  /// Cached articles for [key]; empty when absent or unreadable.
  List<Article> read(String key);

  /// When [key] was last written, or `null` when it never was.
  DateTime? syncedAt(String key);

  /// Drops every cached article and sync timestamp.
  Future<void> clear();
}

/// Shared JSON-string implementation of [ArticleCache].
///
/// Entries are stored as `articles:<key>` (a JSON array string) plus
/// `synced:<key>` (an ISO timestamp). Deliberately no Hive type adapters, so a
/// model change can only cost one skipped cache entry — never a box that fails
/// to open and takes the whole offline experience with it.
abstract class _JsonArticleCache implements ArticleCache {
  static const String _articlePrefix = 'articles:';
  static const String _syncedPrefix = 'synced:';

  /// Raw value stored at [key], or `null`.
  @visibleForTesting
  Object? readRaw(String key);

  /// Stores [value] at [key].
  @visibleForTesting
  Future<void> writeRaw(String key, Object? value);

  /// Removes [key].
  @visibleForTesting
  Future<void> deleteRaw(String key);

  /// Every key currently held by the backing store.
  @visibleForTesting
  Iterable<String> keys();

  @override
  List<Article> read(String key) {
    final String storageKey = '$_articlePrefix$key';
    final Object? raw = readRaw(storageKey);
    if (raw is! String || raw.isEmpty) return const <Article>[];

    final Object? decoded = _tryDecode(raw);
    if (decoded is! List) {
      debugPrint('ArticleCache: unreadable entry "$storageKey" removed');
      unawaited(deleteRaw(storageKey));
      return const <Article>[];
    }

    final List<Article> articles = <Article>[];
    bool pruned = false;
    for (final Object? entry in decoded) {
      if (entry is! Map) {
        pruned = true;
        continue;
      }
      try {
        articles.add(Article.fromJson(entry.cast<String, dynamic>()));
      } catch (error) {
        debugPrint(
          'ArticleCache: dropping corrupt article in "$storageKey": $error',
        );
        pruned = true;
      }
    }

    // Rewrite only the articles key so the original sync time survives.
    if (pruned) unawaited(writeRaw(storageKey, _encode(articles)));
    return articles;
  }

  @override
  DateTime? syncedAt(String key) {
    final Object? raw = readRaw('$_syncedPrefix$key');
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  @override
  Future<void> write(String key, List<Article> articles) async {
    await writeRaw('$_articlePrefix$key', _encode(articles));
    await writeRaw(
      '$_syncedPrefix$key',
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> clear() async {
    final List<String> targets = keys()
        .where(
          (String key) =>
              key.startsWith(_articlePrefix) || key.startsWith(_syncedPrefix),
        )
        .toList(growable: false);
    for (final String key in targets) {
      await deleteRaw(key);
    }
  }

  static String _encode(List<Article> articles) => jsonEncode(
    articles.map((Article article) => article.toJson()).toList(growable: false),
  );

  static Object? _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}

/// Process-lifetime cache used by tests and as a fallback when Hive is
/// unavailable.
class InMemoryArticleCache extends _JsonArticleCache {
  /// Creates a cache, optionally pre-populated with raw storage [seed] so tests
  /// can simulate corrupt entries.
  InMemoryArticleCache([Map<String, Object?>? seed])
    : _values = <String, Object?>{...?seed};

  final Map<String, Object?> _values;

  /// Unmodifiable view of the backing map, for asserting that corrupt entries
  /// were pruned.
  @visibleForTesting
  Map<String, Object?> get rawValues =>
      Map<String, Object?>.unmodifiable(_values);

  @override
  Future<void> init() async {}

  @override
  Object? readRaw(String key) => _values[key];

  @override
  Future<void> writeRaw(String key, Object? value) async {
    _values[key] = value;
  }

  @override
  Future<void> deleteRaw(String key) async {
    _values.remove(key);
  }

  @override
  Iterable<String> keys() => _values.keys.toList(growable: false);
}

/// Hive-backed cache of JSON strings; see [_JsonArticleCache] for the format.
class HiveArticleCache extends _JsonArticleCache {
  /// Creates a cache bound to [boxName]; call [init] (or [open]) before use.
  HiveArticleCache({String boxName = 'slnews_cache'}) : _name = boxName;

  /// Opens the box and returns a ready cache.
  static Future<HiveArticleCache> open({
    String boxName = 'slnews_cache',
  }) async {
    final HiveArticleCache cache = HiveArticleCache(boxName: boxName);
    await cache.init();
    return cache;
  }

  final String _name;
  Box<dynamic>? _box;

  @override
  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    try {
      _box = Hive.isBoxOpen(_name)
          ? Hive.box<dynamic>(_name)
          : await Hive.openBox<dynamic>(_name);
    } catch (error) {
      debugPrint('HiveArticleCache: could not open "$_name": $error');
      _box = null;
    }
  }

  @override
  Object? readRaw(String key) => _box?.get(key);

  @override
  Future<void> writeRaw(String key, Object? value) async {
    await _box?.put(key, value);
  }

  @override
  Future<void> deleteRaw(String key) async {
    await _box?.delete(key);
  }

  @override
  Iterable<String> keys() =>
      _box?.keys.whereType<String>().toList(growable: false) ??
      const <String>[];
}
