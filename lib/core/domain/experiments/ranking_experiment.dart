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

/// Phase 3A seed experiment: disabled until the guardrail thresholds in
/// `docs/EXPERIMENTS.md` are met.
const RankingExperimentConfig forYouRankingExperiment = RankingExperimentConfig(
  key: 'for_you_ranker_v1',
  enabled: false,
  treatmentPercent: 10,
);
