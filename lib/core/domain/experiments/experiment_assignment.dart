import 'package:flutter/foundation.dart';

/// Which side of a ranking experiment a device is assigned to.
enum ExperimentVariant { control, treatment }

/// Sticky, anonymous experiment assignment.
///
/// The assignment is derived from an install-local seed, never an account id,
/// so signing in/out cannot move a device between variants and the server never
/// learns a user-level assignment.
@immutable
class ExperimentAssignment {
  const ExperimentAssignment({
    required this.experimentKey,
    required this.variant,
    required this.bucket,
    required this.enabled,
  });

  final String experimentKey;
  final ExperimentVariant variant;

  /// Bucket in `0..999`. `-1` for a disabled experiment.
  final int bucket;
  final bool enabled;

  bool get isTreatment => enabled && variant == ExperimentVariant.treatment;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'experimentKey': experimentKey,
    'variant': variant.name,
    'bucket': bucket,
    'enabled': enabled,
  };

  @override
  bool operator ==(Object other) =>
      other is ExperimentAssignment &&
      other.experimentKey == experimentKey &&
      other.variant == variant &&
      other.bucket == bucket &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(experimentKey, variant, bucket, enabled);
}

/// Deterministic bucketing for local A/B experiments.
///
/// This is intentionally a pure function: the same anonymous seed and key
/// always produce the same bucket, and there is no random state per build.
abstract final class ExperimentAssigner {
  static const int bucketCount = 1000;

  static ExperimentAssignment assign({
    required String experimentKey,
    required String anonymousSeed,
    required bool enabled,
    int treatmentPercent = 10,
  }) {
    if (!enabled) {
      return ExperimentAssignment(
        experimentKey: experimentKey,
        variant: ExperimentVariant.control,
        bucket: -1,
        enabled: false,
      );
    }
    final int percentage = treatmentPercent.clamp(0, 100);
    final int bucket = _hash('$experimentKey|$anonymousSeed') % bucketCount;
    final bool treatment = bucket < percentage * (bucketCount ~/ 100);
    return ExperimentAssignment(
      experimentKey: experimentKey,
      variant: treatment
          ? ExperimentVariant.treatment
          : ExperimentVariant.control,
      bucket: bucket,
      enabled: true,
    );
  }

  /// FNV-1a/32; stable across platforms and Dart releases.
  static int _hash(String value) {
    int hash = 0x811c9dc5;
    for (final int unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
