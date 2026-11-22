/// Ad surfaces known to the app and the backend.
enum AdPlacement {
  feed('feed'),
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
