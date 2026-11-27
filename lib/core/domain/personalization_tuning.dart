/// Central tuning for the on-device ranking model.
///
/// These values are intentionally explicit rather than hidden in call sites so
/// they can be adjusted from observed reader behaviour without touching the
/// algorithm. The current balance favours deliberate signals (saves/likes and
/// completed reads) over opens, and explores one slot per six stories rather
/// than letting a single strong publisher dominate.
abstract final class PersonalizationTuning {
  // Engagement event weights.
  static const double openWeight = 0.2;
  static const double saveWeight = 5;
  static const double likeWeight = 4;
  static const double readWeight = 1;
  static const double deepReadWeight = 3;
  static const double skipWeight = -2.5;
  static const double dismissWeight = -6;
  static const double tagAffinityFactor = 0.5;

  // Read classification.
  static const Duration skipMaxDwell = Duration(seconds: 6);
  static const double skipMaxProgress = 0.12;
  static const Duration deepMinDwell = Duration(seconds: 15);
  static const double deepMinProgress = 0.6;

  // Explicit follow boosts.
  static const int followTopicScore = 24;
  static const int followPublisherScore = 20;
  static const int followTagScore = 8;
  static const int followTagCap = 16;

  // Affinity, freshness and editorial signals.
  static const int affinityCeiling = 12;
  static const int freshSixHours = 18;
  static const int freshDay = 13;
  static const int freshThreeDays = 7;
  static const int freshWeek = 2;
  static const int breakingBoost = 14;
  static const int localBoost = 6;
  static const int alreadyReadPenalty = -12;
  static const int savedStoryBoost = 10;
  static const int likedStoryBoost = 8;
  static const int explorationMaxBonus = 3;

  // Diversity and exploration.
  static const int maxPerPublisherInWindow = 2;
  static const int maxPerCategoryInWindow = 3;
  static const int diversityWindow = 12;
  static const int explorationInterval = 6;
  static const int explorationReserve = 1;

  // How many stories a followed topic/publisher can contribute per build.
  static const int followedFeedLimit = 6;

  /// Classifies a finished reader session from dwell time and scroll progress.
  static ReadEngagement classifyRead({
    required Duration dwell,
    required double progress,
  }) {
    final double boundedProgress = progress.clamp(0.0, 1.0);
    if (dwell < skipMaxDwell && boundedProgress < skipMaxProgress) {
      return ReadEngagement.skip;
    }
    if (dwell >= deepMinDwell && boundedProgress >= deepMinProgress) {
      return ReadEngagement.deep;
    }
    return ReadEngagement.read;
  }

  /// Weight applied to a read event after [classifyRead].
  static double readWeightFor(ReadEngagement engagement) =>
      switch (engagement) {
        ReadEngagement.skip => skipWeight,
        ReadEngagement.read => readWeight,
        ReadEngagement.deep => deepReadWeight,
      };
}

enum ReadEngagement { skip, read, deep }
