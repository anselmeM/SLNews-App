import 'package:flutter/foundation.dart';

/// Configuration for the For You ranking experiment.
///
/// The experiment is disabled by default and has no remote endpoint yet. Phase
/// 3B will replace [forYouRankingExperiment] with a validated remote config; the
/// local assignment and guardrail code can land first without changing ranking.
@immutable
class RankingExperimentConfig {
  const RankingExperimentConfig({
    required this.key,
    required this.enabled,
    required this.treatmentPercent,
  });

  final String key;
  final bool enabled;
  final int treatmentPercent;

  bool get isActive => enabled && treatmentPercent > 0;
}

/// Wire model for a future remote experiment endpoint.
///
/// Parsing is strict and clamping is local. Any malformed or absent payload
/// leaves the current local ranker and the disabled experiment in place.
@immutable
class RemoteRankingExperimentConfig {
  const RemoteRankingExperimentConfig({
    required this.key,
    required this.enabled,
    required this.treatmentPercent,
    required this.killSwitch,
  });

  final String key;
  final bool enabled;
  final int treatmentPercent;
  final bool killSwitch;

  static RemoteRankingExperimentConfig? tryParse(Object? wire) {
    if (wire is! Map) return null;
    final Object? key = wire['key'];
    final Object? enabled = wire['enabled'];
    final Object? treatment = wire['treatmentPercent'];
    final Object? kill = wire['killSwitch'];
    if (key is! String || key.trim().isEmpty) return null;
    if (enabled is! bool || treatment is! num || kill is! bool) return null;
    if (!treatment.isFinite) return null;
    final int percent = treatment.toInt();
    if (percent < 0 || percent > 100) return null;
    return RemoteRankingExperimentConfig(
      key: key.trim(),
      enabled: enabled,
      treatmentPercent: percent,
      killSwitch: kill,
    );
  }

  /// A kill switch always wins over an enabled remote payload.
  RankingExperimentConfig apply(RankingExperimentConfig fallback) {
    if (killSwitch) {
      return RankingExperimentConfig(
        key: fallback.key,
        enabled: false,
        treatmentPercent: fallback.treatmentPercent,
      );
    }
    return RankingExperimentConfig(
      key: key,
      enabled: enabled && treatmentPercent > 0,
      treatmentPercent: treatmentPercent,
    );
  }
}

/// Phase 3A seed experiment: disabled until the guardrail thresholds in
/// `docs/EXPERIMENTS.md` are met.
const RankingExperimentConfig forYouRankingExperiment = RankingExperimentConfig(
  key: 'for_you_ranker_v1',
  enabled: false,
  treatmentPercent: 10,
);
