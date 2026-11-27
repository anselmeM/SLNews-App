import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/preferences_store.dart';
import '../domain/experiments/experiment_assignment.dart';
import '../domain/experiments/ranking_experiment.dart';
import 'app_providers.dart';

/// Persisted anonymous install seed used only for experiment bucketing.
const String experimentInstallSeedKey = 'experiments.installSeed.v1';

/// Install-local anonymous seed.
///
/// It is never derived from the account, device advertising id or location.
/// When local storage is unavailable a session-local seed is used so bucketing
/// remains deterministic for this run without creating a new persisted identity.
final Provider<String> anonymousExperimentSeedProvider = Provider<String>((
  Ref ref,
) {
  PreferencesStore? store;
  String? stored;
  try {
    final PreferencesStore opened = ref.read(preferencesStoreProvider);
    store = opened;
    stored = opened.string(experimentInstallSeedKey);
  } catch (_) {
    store = null;
  }
  if (stored != null && _isValidSeed(stored)) return stored;
  final String seed = _generateSeed();
  if (store != null && store.isAvailable) {
    unawaited(
      store.putString(experimentInstallSeedKey, seed).catchError((Object _) {}),
    );
  }
  return seed;
}, name: 'anonymousExperimentSeed');

/// Config seam for tests and the later remote-config rollout.
final Provider<RankingExperimentConfig> forYouRankingExperimentConfigProvider =
    Provider<RankingExperimentConfig>(
      (Ref _) => forYouRankingExperiment,
      name: 'forYouRankingExperimentConfig',
    );

/// Sticky assignment for the For You ranker.
///
/// Phase 3A only computes and stores this locally; the ranking path still uses
/// the single tuned model because the experiment is disabled.
final Provider<ExperimentAssignment> forYouRankingAssignmentProvider =
    Provider<ExperimentAssignment>((Ref ref) {
      final RankingExperimentConfig config = ref.watch(
        forYouRankingExperimentConfigProvider,
      );
      return ExperimentAssigner.assign(
        experimentKey: config.key,
        anonymousSeed: ref.watch(anonymousExperimentSeedProvider),
        enabled: config.isActive,
        treatmentPercent: config.treatmentPercent,
      );
    }, name: 'forYouRankingAssignment');

bool _isValidSeed(String value) => RegExp(r'^[0-9a-f]{32}$').hasMatch(value);

String _generateSeed() {
  final Random random = Random.secure();
  return List<String>.generate(
    16,
    (int _) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
