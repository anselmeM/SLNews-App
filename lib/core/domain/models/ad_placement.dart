/// Ad surfaces known to the app and the backend.
///
/// [feed] is the For You pool: the server selects and orders at most two units
/// for it. [newsStream], [sportsStream] and [articleEnd] are single-unit
/// surfaces. The app renders whatever the server returns, in the order it sent;
/// it never re-sorts or rotates sold units itself.
enum AdPlacement {
  feed('feed'),
  newsStream('news_stream'),
  sportsStream('sports_stream'),
  articleEnd('article_end');

  const AdPlacement(this.wire);

  /// Stable placement key used by the API and the admin console.
  final String wire;

  static AdPlacement? tryParse(String? value) {
    final String normalized = (value ?? '').trim();
    for (final AdPlacement placement in values) {
      if (placement.wire == normalized) return placement;
    }
    return null;
  }
}
