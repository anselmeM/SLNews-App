import '../models/ad_unit.dart';

/// Native-style inline placements shown in the content stream.
abstract interface class AdRepository {
  /// Units in rotation for a placement key (`sports_stream`, `feed`, ...).
  Future<List<AdUnit>> units({String placement = 'default'});

  /// Synchronous read of the last loaded rotation.
  List<AdUnit> get cachedUnits;
}
