import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/ad_unit.dart';
import '../../domain/repositories/ad_repository.dart';
import '../seed/seed_loader.dart';
import '../sources/sponsorship_source.dart';

/// House ad rotation served from the bundled seed.
///
/// Units are local creative, so there is no network path and no targeting: the
/// same rotation is returned for every placement until a real ad decisioning
/// layer exists.
class DefaultAdRepository implements AdRepository {
  /// Creates a repository over [seedLoader].
  DefaultAdRepository({required SeedLoader seedLoader, this.sponsorships})
    : _seeds = seedLoader {
    unawaited(_ready);
  }

  /// Upper bound on units returned for one placement.
  static const int maxUnits = 6;

  final SeedLoader _seeds;

  /// Sold units, tried before the seeded house rotation.
  final SponsorshipSource? sponsorships;

  List<AdUnit> _units = const <AdUnit>[];

  late final Future<void> _ready = _hydrate();

  /// Resolves once the seeded rotation is loaded.
  Future<void> ready() => _ready;

  @override
  List<AdUnit> get cachedUnits => List<AdUnit>.unmodifiable(_units);

  @override
  Future<List<AdUnit>> units({String placement = 'default'}) async {
    await _ready;
    if (sponsorships != null) {
      final List<AdUnit> sold = await sponsorships!.units(placement);
      if (sold.isNotEmpty) {
        return sold.take(maxUnits).toList(growable: false);
      }
    }
    return _units.take(maxUnits).toList(growable: false);
  }

  Future<void> _hydrate() async {
    try {
      _units = (await _seeds.load()).ads;
    } catch (error) {
      debugPrint('DefaultAdRepository: seed unavailable: $error');
    }
  }
}
