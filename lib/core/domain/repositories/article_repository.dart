import '../models/article.dart';

/// Read access to editorial content.
///
/// Implementations are offline-first: they return cached or bundled content
/// immediately when the network is unavailable and never throw for an empty
/// feed. A hard failure is reserved for corrupt local state.
abstract interface class ArticleRepository {
  /// Breaking/staff-picked stories for the For You hero carousel.
  Future<List<Article>> topStories({int limit = 8});

  /// Latest stories for a category slug (`top`, `politics`, ...).
  Future<List<Article>> byCategory(String categoryId, {int limit = 30});

  /// Latest stories from one outlet, newest first.
  ///
  /// Used by the publisher page; a publisher with no local stories returns an
  /// empty list rather than throwing.
  Future<List<Article>> byPublisher(String publisherId, {int limit = 30});

  /// Single story for the reader; `null` when it is unknown locally.
  Future<Article?> byId(String id);

  /// Full-text search across cached titles, summaries and tags.
  Future<List<Article>> search(String query, {int limit = 20});

  /// Forces a network refresh; resolves to the stories that were ingested.
  Future<List<Article>> refresh();

  /// True when the last refresh fell back to cache or bundled seed content.
  bool get isOffline;

  /// Timestamp of the last successful ingest, or `null` before the first one.
  DateTime? get lastSyncedAt;
}
