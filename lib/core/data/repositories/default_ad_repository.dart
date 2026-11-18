import 'dart:async';

import '../../domain/models/ad_unit.dart';
import '../../domain/repositories/ad_repository.dart';
import '../seed/seed_loader.dart';
import '../sources/sponsorship_source.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

import '../../utils/time_ago.dart';

/// House ad rotation served from the bundled seed.
///
/// Units are local creative, so there is no network path and no targeting. The
/// seeded rotation used to be returned in the same order for every placement and
/// every launch, which is how a reader saw the same house ad indefinitely. It is
/// now rotated deterministically: the start offset moves with the UTC day and
/// with the placement, so a placement keeps a stable creative for a day (cache
/// and tests stay predictable) while the feed, sports and article placements
/// show different units from each other.
class DefaultAdRepository implements AdRepository {
  /// Creates a repository over [seedLoader].
  DefaultAdRepository({
    required SeedLoader seedLoader,
    this.sponsorships,
    DateTime Function()? now,
  }) : _seeds = seedLoader,
       // `appNow` is the app's single clock seam (relative labels already use
       // it), so the golden harness freezing it also freezes this rotation.
       _now = now ?? appNow {
    unawaited(_ready);
  }

  /// Upper bound on units returned for one placement.
  static const int maxUnits = 6;

  final SeedLoader _seeds;

  /// Sold units, tried before the seeded house rotation.
  final SponsorshipSource? sponsorships;

  /// Clock seam for the daily rotation.
  final DateTime Function() _now;

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
    return _rotated(placement).take(maxUnits).toList(growable: false);
  }

  /// The seeded rotation starting at a placement- and day-dependent offset.
  List<AdUnit> _rotated(String placement) {
    if (_units.length < 2) return _units;
    final int day = _now().toUtc().difference(DateTime.utc(2026)).inDays;
    // codeUnits rather than hashCode: stable across runs and platforms, which
    // keeps the choice reproducible for tests and for a given placement.
    final int placementSeed = placement.codeUnits.fold<int>(
      0,
      (int sum, int unit) => sum + unit,
    );
    final int start = (day + placementSeed) % _units.length;
    return <AdUnit>[..._units.skip(start), ..._units.take(start)];
  }

  Future<void> _hydrate() async {
    try {
      _units = (await _seeds.load()).ads;
    } catch (error) {
      AppLog.debug('DefaultAdRepository: seed unavailable: $error');
    }
  }
}
