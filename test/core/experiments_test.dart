import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/domain/experiments/experiment_assignment.dart';
import 'package:slnews_mobile/core/domain/experiments/ranking_experiment.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/experiments.dart';

void main() {
  test('assignment is deterministic and sticky for a seed', () {
    final ExperimentAssignment first = ExperimentAssigner.assign(
      experimentKey: 'ranker',
      anonymousSeed: 'a' * 32,
      enabled: true,
      treatmentPercent: 25,
    );
    final ExperimentAssignment second = ExperimentAssigner.assign(
      experimentKey: 'ranker',
      anonymousSeed: 'a' * 32,
      enabled: true,
      treatmentPercent: 25,
    );

    expect(second, first);
    expect(first.bucket, inInclusiveRange(0, 999));
    expect(first.enabled, isTrue);
  });

  test('assignment splits roughly by treatment percent', () {
    int treated = 0;
    for (int i = 0; i < 5000; i++) {
      final ExperimentAssignment assignment = ExperimentAssigner.assign(
        experimentKey: 'ranker',
        anonymousSeed: i.toString(),
        enabled: true,
        treatmentPercent: 10,
      );
      if (assignment.isTreatment) treated++;
    }
    expect(treated, greaterThan(400));
    expect(treated, lessThan(600));
  });

  test('disabled experiments assign control without a bucket', () {
    final ExperimentAssignment assignment = ExperimentAssigner.assign(
      experimentKey: 'ranker',
      anonymousSeed: 'seed',
      enabled: false,
    );
    expect(assignment.variant, ExperimentVariant.control);
    expect(assignment.bucket, -1);
    expect(assignment.isTreatment, isFalse);
  });

  test('0 and 100 percent are honoured', () {
    expect(
      ExperimentAssigner.assign(
        experimentKey: 'ranker',
        anonymousSeed: 'seed',
        enabled: true,
        treatmentPercent: 0,
      ).variant,
      ExperimentVariant.control,
    );
    expect(
      ExperimentAssigner.assign(
        experimentKey: 'ranker',
        anonymousSeed: 'seed',
        enabled: true,
        treatmentPercent: 100,
      ).variant,
      ExperimentVariant.treatment,
    );
  });

  test('anonymous seed is generated once and persisted per install', () {
    final InMemoryPreferencesStore store = InMemoryPreferencesStore();
    final ProviderContainer first = ProviderContainer(
      overrides: [preferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(first.dispose);

    final String seed = first.read(anonymousExperimentSeedProvider);
    expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(seed), isTrue);
    expect(first.read(anonymousExperimentSeedProvider), seed);
    expect(store.string(experimentInstallSeedKey), seed);

    final ProviderContainer second = ProviderContainer(
      overrides: [preferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(second.dispose);
    expect(second.read(anonymousExperimentSeedProvider), seed);
  });

  test('assignment uses the config and seed providers', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        anonymousExperimentSeedProvider.overrideWithValue('b' * 32),
        forYouRankingExperimentConfigProvider.overrideWithValue(
          const RankingExperimentConfig(
            key: 'ranker',
            enabled: true,
            treatmentPercent: 100,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final ExperimentAssignment assignment = container.read(
      forYouRankingAssignmentProvider,
    );
    expect(assignment.enabled, isTrue);
    expect(assignment.variant, ExperimentVariant.treatment);
    expect(assignment.experimentKey, 'ranker');
  });

  test('remote config rejects malformed payloads', () {
    expect(RemoteRankingExperimentConfig.tryParse(null), isNull);
    expect(RemoteRankingExperimentConfig.tryParse('bad'), isNull);
    expect(
      RemoteRankingExperimentConfig.tryParse(<String, dynamic>{
        'key': 'ranker',
        'enabled': true,
        'treatmentPercent': 101,
        'killSwitch': false,
      }),
      isNull,
    );
    final RemoteRankingExperimentConfig? valid =
        RemoteRankingExperimentConfig.tryParse(<String, dynamic>{
          'key': 'ranker',
          'enabled': true,
          'treatmentPercent': 10,
          'killSwitch': false,
        });
    expect(valid, isNotNull);
    expect(valid!.treatmentPercent, 10);
  });

  test('a remote kill switch disables an enabled payload', () {
    const RemoteRankingExperimentConfig remote = RemoteRankingExperimentConfig(
      key: 'ranker',
      enabled: true,
      treatmentPercent: 10,
      killSwitch: true,
    );
    final RankingExperimentConfig applied = remote.apply(
      forYouRankingExperiment,
    );
    expect(applied.enabled, isFalse);
    expect(applied.key, forYouRankingExperiment.key);
  });

  test('remote source failures fall back to no config', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        experimentConfigSourceProvider.overrideWithValue(
          _ThrowingConfigSource(),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(remoteRankingExperimentConfigProvider.future),
      isNull,
    );
  });

  test('the default experiment is disabled', () {
    expect(forYouRankingExperiment.enabled, isFalse);
    expect(forYouRankingExperiment.isActive, isFalse);
    expect(ExperimentAssigner.bucketCount, 1000);
  });
}

class _ThrowingConfigSource implements RankingExperimentConfigSource {
  @override
  Future<Object?> fetch() async => throw StateError('offline');
}
