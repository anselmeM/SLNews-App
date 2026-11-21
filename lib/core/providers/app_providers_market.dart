part of 'app_providers.dart';

final FutureProvider<List<AdUnit>> forYouAdsProvider =
    FutureProvider<List<AdUnit>>(
      (Ref ref) => ref.watch(adRepositoryProvider).units(placement: 'feed'),
      name: 'forYouAds',
    );

/// Reads the Markets currency board.
///
/// Keyless endpoint, so the only dependency is the shared [ApiClient] that
/// AppBootstrap already owns (and every test already overrides/replaces).
final Provider<MarketRateSource> marketRateSourceProvider =
    Provider<MarketRateSource>(
      (Ref ref) => MarketRateSource(ref.watch(apiClientProvider)),
      name: 'marketRateSource',
    );

/// Preference key holding the last board we managed to read.
const String marketCacheKey = 'markets.lastSnapshot';

/// The Markets board for the interactive card: fresh rates when the service
/// answers, otherwise the last board we saw, otherwise `null`.
///
/// Never throws: the module is a bonus surface, so an offline reader sees the
/// most recent rates (with their timestamp) instead of an error.
final FutureProvider<MarketSnapshot?> marketSnapshotProvider =
    FutureProvider<MarketSnapshot?>((Ref ref) async {
      PreferencesStore? store;
      try {
        store = ref.watch(preferencesStoreProvider);
      } on UnimplementedError {
        // A bare test scope without storage: still useful, just uncached.
        store = null;
      }

      final MarketSnapshot? cached = _cachedBoard(store);
      final MarketSnapshot? fresh = await ref
          .watch(marketRateSourceProvider)
          .fetch();
      if (fresh != null) {
        if (store != null) {
          await store.putString(marketCacheKey, jsonEncode(fresh.toJson()));
        }
        return fresh;
      }
      return cached;
    }, name: 'marketSnapshot');

MarketSnapshot? _cachedBoard(PreferencesStore? store) {
  final String? raw = store?.string(marketCacheKey);
  if (raw == null || raw.isEmpty) return null;
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is Map) {
      return MarketSnapshot.fromJson(<String, dynamic>{
        for (final MapEntry<Object?, Object?> entry in decoded.entries)
          '${entry.key}': entry.value,
      });
    }
  } catch (error) {
    AppLog.debug('marketSnapshot: cached board unreadable ($error)');
  }
  return null;
}

/// Reads the Stocks index board (keyless chart endpoint, cached).
final Provider<IndexQuoteSource> indexQuoteSourceProvider =
    Provider<IndexQuoteSource>(
      (Ref ref) => IndexQuoteSource(ref.watch(apiClientProvider)),
      name: 'indexQuoteSource',
    );

/// Preference key holding the last index board we managed to read.
const String indexBoardCacheKey = 'stocks.lastBoard';

/// The board for the Stocks section and page: fresh quotes when the service
/// answers, otherwise the last board we saw, otherwise `null` (the section then
/// hides instead of inventing numbers).
final FutureProvider<IndexBoard?> indexBoardProvider =
    FutureProvider<IndexBoard?>((Ref ref) async {
      PreferencesStore? store;
      try {
        store = ref.watch(preferencesStoreProvider);
      } on UnimplementedError {
        store = null;
      }

      IndexBoard? cached;
      final String? raw = store?.string(indexBoardCacheKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final Object? decoded = jsonDecode(raw);
          if (decoded is Map) {
            cached = IndexBoard.fromJson(<String, dynamic>{
              for (final MapEntry<Object?, Object?> entry in decoded.entries)
                '${entry.key}': entry.value,
            });
          }
        } catch (error) {
          AppLog.debug('indexBoard: cached board unreadable ($error)');
        }
      }

      final IndexBoard? fresh = await ref
          .watch(indexQuoteSourceProvider)
          .fetch();
      if (fresh != null) {
        if (store != null) {
          await store.putString(indexBoardCacheKey, jsonEncode(fresh.toJson()));
        }
        return fresh;
      }
      return cached;
    }, name: 'indexBoard');
