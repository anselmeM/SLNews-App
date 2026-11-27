import 'package:flutter/foundation.dart';

import 'feed_mix.dart';
import 'personalization_tuning.dart';
import 'models/article.dart';

/// Local, privacy-preserving signals used to rank For You.
///
/// Nothing here leaves the device. Explicit follows are the strong signal;
/// reading history, saved stories and likes provide a softer affinity signal.
@immutable
class ReaderSignals {
  const ReaderSignals({
    this.followedIds = const <String>{},
    this.readIds = const <String>{},
    this.savedIds = const <String>{},
    this.likedIds = const <String>{},
    this.topicAffinity = const <String, double>{},
    this.publisherAffinity = const <String, double>{},
  });

  /// Explicit `topic:`, `publisher:`, `city:` and sports follow ids.
  final Set<String> followedIds;

  /// Recently opened story ids on this device.
  final Set<String> readIds;

  /// Saved story ids on this device/account.
  final Set<String> savedIds;

  /// Liked story ids on this device/account.
  final Set<String> likedIds;

  /// Raw category affinity counts derived from the local signals above.
  final Map<String, double> topicAffinity;

  /// Raw publisher affinity counts derived from the local signals above.
  final Map<String, double> publisherAffinity;

  bool get hasExplicitFollows => followedIds.isNotEmpty;

  bool get hasBehaviorSignals =>
      readIds.isNotEmpty ||
      savedIds.isNotEmpty ||
      likedIds.isNotEmpty ||
      topicAffinity.isNotEmpty ||
      publisherAffinity.isNotEmpty;

  bool get isEmpty => !hasExplicitFollows && !hasBehaviorSignals;

  ReaderSignals copyWith({
    Set<String>? followedIds,
    Set<String>? readIds,
    Set<String>? savedIds,
    Set<String>? likedIds,
    Map<String, double>? topicAffinity,
    Map<String, double>? publisherAffinity,
  }) {
    return ReaderSignals(
      followedIds: followedIds ?? this.followedIds,
      readIds: readIds ?? this.readIds,
      savedIds: savedIds ?? this.savedIds,
      likedIds: likedIds ?? this.likedIds,
      topicAffinity: topicAffinity ?? this.topicAffinity,
      publisherAffinity: publisherAffinity ?? this.publisherAffinity,
    );
  }
}

/// Adds persistent profile affinity to the current-pool signal affinity.
///
/// The profile is keyed by categories/publishers plus last-seen tags; the
/// current-pool signals carry tags from freshly read/saved stories. Merging
/// preserves both instead of replacing tags with category-only profile keys.
Map<String, double> mergeAffinityMaps(
  Map<String, double> current,
  Map<String, double> persistent,
) {
  if (persistent.isEmpty) return current;
  final Map<String, double> merged = <String, double>{...current};
  persistent.forEach((String key, double value) {
    merged[key] = (merged[key] ?? 0) + value;
  });
  return merged;
}

/// Builds raw affinity from the stories the reader has interacted with that are
/// still known locally. Unknown/old ids are simply ignored; Phase 2 replaces
/// this with a persistent interest profile.
ReaderSignals buildReaderSignals({
  required Iterable<Article> knownArticles,
  Set<String> followedIds = const <String>{},
  Set<String> readIds = const <String>{},
  Set<String> savedIds = const <String>{},
  Set<String> likedIds = const <String>{},
}) {
  final Map<String, double> topics = <String, double>{};
  final Map<String, double> publishers = <String, double>{};

  void add(Map<String, double> target, String key, double weight) {
    if (key.trim().isEmpty) return;
    target[key] = (target[key] ?? 0) + weight;
  }

  // The same story can arrive from the top feed, a category feed and a
  // followed-publisher feed. Count it once or its affinity is multiplied.
  final Map<String, Article> unique = <String, Article>{};
  for (final Article article in knownArticles) {
    unique.putIfAbsent(article.id, () => article);
  }

  for (final Article article in unique.values) {
    double weight = 0;
    if (readIds.contains(article.id)) weight += 1;
    if (savedIds.contains(article.id)) {
      weight += PersonalizationTuning.saveWeight;
    }
    if (likedIds.contains(article.id)) {
      weight += PersonalizationTuning.likeWeight;
    }
    if (weight <= 0) continue;
    add(topics, article.categoryId, weight);
    add(publishers, article.publisher.id, weight);
    for (final String tag in article.tags.take(3)) {
      add(
        topics,
        tag.toLowerCase(),
        weight * PersonalizationTuning.tagAffinityFactor,
      );
    }
  }

  return ReaderSignals(
    followedIds: followedIds,
    readIds: readIds,
    savedIds: savedIds,
    likedIds: likedIds,
    topicAffinity: topics,
    publisherAffinity: publishers,
  );
}

/// Deterministic, explainable ranking for the For You feed.
///
/// This is deliberately not a social-media-scale ML model. It combines explicit
/// follows with lightweight local behaviour, then applies diversity caps. Pure
/// functions keep the rules testable and the result stable across rebuilds.
abstract final class PersonalizationEngine {
  static const int maxPerPublisherInWindow =
      PersonalizationTuning.maxPerPublisherInWindow;
  static const int maxPerCategoryInWindow =
      PersonalizationTuning.maxPerCategoryInWindow;
  static const int diversityWindow = PersonalizationTuning.diversityWindow;
  static const int followedRailLimit = 5;

  /// Higher is more relevant. The score is intentionally bounded and made of
  /// named, inspectable parts rather than a learned black box.
  static int score(
    Article article,
    ReaderSignals signals, {
    DateTime? now,
    bool includeExploration = true,
  }) {
    final int follow = _followScore(article, signals.followedIds);
    final int topic = _bestAffinityScore(article, signals.topicAffinity);
    final int publisher = _affinityScore(
      signals.publisherAffinity,
      article.publisher.id,
    );
    final int direct =
        (signals.savedIds.contains(article.id)
            ? PersonalizationTuning.savedStoryBoost
            : 0) +
        (signals.likedIds.contains(article.id)
            ? PersonalizationTuning.likedStoryBoost
            : 0);
    final int readPenalty =
        signals.readIds.contains(article.id) &&
            !signals.savedIds.contains(article.id) &&
            !signals.likedIds.contains(article.id)
        ? PersonalizationTuning.alreadyReadPenalty
        : 0;
    final int freshness = _freshnessScore(article, now ?? DateTime.now());
    final int breaking = article.isBreaking
        ? PersonalizationTuning.breakingBoost
        : 0;
    final int local = FeedMix.isSierraLeone(article)
        ? PersonalizationTuning.localBoost
        : 0;
    final int exploration = includeExploration
        ? _explorationScore(article, now ?? DateTime.now())
        : 0;

    return follow +
        topic +
        publisher +
        direct +
        readPenalty +
        freshness +
        breaking +
        local +
        exploration;
  }

  /// Comparator used inside one [FeedMix] audience bucket.
  static int compare(
    Article a,
    Article b,
    ReaderSignals signals, {
    DateTime? now,
  }) {
    if (a.isBreaking != b.isBreaking) return a.isBreaking ? -1 : 1;
    final int byScore = score(
      b,
      signals,
      now: now,
    ).compareTo(score(a, signals, now: now));
    if (byScore != 0) return byScore;
    return b.publishedAt.compareTo(a.publishedAt);
  }

  /// Explicit-follow matches only. Used by the "From your follows" rail so the
  /// rail is always explainable ("you follow this").
  static int followMatch(Article article, Set<String> followedIds) =>
      _followScore(article, followedIds);

  /// Selects the followed stories rail, newest/relevant first and without
  /// duplicate publishers or categories in the small top set.
  static List<Article> followedStories(
    Iterable<Article> articles,
    ReaderSignals signals, {
    int limit = followedRailLimit,
    Set<String> excludeIds = const <String>{},
  }) {
    if (!signals.hasExplicitFollows || limit <= 0) {
      return const <Article>[];
    }
    final List<Article> matched = <Article>[
      for (final Article article in articles)
        if (!excludeIds.contains(article.id) &&
            !FeedMix.isSports(article) &&
            _followScore(article, signals.followedIds) > 0)
          article,
    ];
    matched.sort((Article a, Article b) {
      // Local followed coverage outranks international followed coverage even
      // when the international story has stronger engagement.
      final int byAudience = FeedMix.priorityOf(a)
          .compareTo(FeedMix.priorityOf(b));
      if (byAudience != 0) return byAudience;
      final int byScore = score(
        b,
        signals,
        includeExploration: false,
      ).compareTo(score(a, signals, includeExploration: false));
      if (byScore != 0) return byScore;
      return b.publishedAt.compareTo(a.publishedAt);
    });
    return diversify(matched, limit: limit);
  }

  /// Applies publisher/category diversity caps to the first
  /// [diversityWindow] slots while preserving all remaining stories.
  static List<Article> diversify(
    Iterable<Article> ranked, {
    int maxPerPublisher = maxPerPublisherInWindow,
    int maxPerCategory = maxPerCategoryInWindow,
    int window = diversityWindow,
    int? limit,
  }) {
    final List<Article> all = ranked.toList(growable: false);
    if (all.isEmpty) return const <Article>[];

    // Keep audience buckets contiguous. Applying caps globally used to append a
    // capped local story after selected international stories, which broke the
    // Sierra Leone-first rule. Deferred stories now stay inside their bucket.
    final Map<FeedAudience, List<Article>> buckets =
        <FeedAudience, List<Article>>{};
    for (final Article article in all) {
      buckets
          .putIfAbsent(FeedMix.audienceOf(article), () => <Article>[])
          .add(article);
    }

    final List<Article> result = <Article>[];
    final Map<String, int> publishers = <String, int>{};
    final Map<String, int> categories = <String, int>{};

    for (final FeedAudience audience in FeedAudience.values) {
      final List<Article>? bucket = buckets[audience];
      if (bucket == null || bucket.isEmpty) continue;
      final List<Article> selected = <Article>[];
      final List<Article> deferred = <Article>[];
      for (final Article article in bucket) {
        if (result.length + selected.length >= window) {
          deferred.add(article);
          continue;
        }
        final int publisherCount = publishers[article.publisher.id] ?? 0;
        final int categoryCount = categories[article.categoryId] ?? 0;
        if (publisherCount >= maxPerPublisher ||
            categoryCount >= maxPerCategory) {
          deferred.add(article);
          continue;
        }
        selected.add(article);
        publishers[article.publisher.id] = publisherCount + 1;
        categories[article.categoryId] = categoryCount + 1;
      }
      result.addAll(selected);
      result.addAll(deferred);
    }

    if (limit == null) return result;
    return result.take(limit).toList(growable: false);
  }

  /// Reserves a small number of in-bucket positions for a less-personalized
  /// story. The reserved story is swapped within the same [FeedAudience] bucket
  /// so exploration never moves international news ahead of Sierra Leone news.
  static const int explorationInterval =
      PersonalizationTuning.explorationInterval;
  static const int explorationReserve =
      PersonalizationTuning.explorationReserve;

  static List<Article> reserveExploration(
    Iterable<Article> ranked,
    ReaderSignals signals, {
    int interval = explorationInterval,
    int reserve = explorationReserve,
  }) {
    final List<Article> result = ranked.toList(growable: true);
    if (signals.isEmpty || result.length <= interval || reserve <= 0) {
      return result;
    }

    int placed = 0;
    for (
      int slot = interval - 1;
      slot < result.length && placed < reserve;
      slot += interval
    ) {
      final Article target = result[slot];
      if (_isExplorationCandidate(target, signals)) {
        placed++;
        continue;
      }
      int candidateIndex = -1;
      for (int index = slot + 1; index < result.length; index++) {
        final Article candidate = result[index];
        if (FeedMix.priorityOf(candidate) != FeedMix.priorityOf(target)) {
          continue;
        }
        if (!_isExplorationCandidate(candidate, signals)) continue;
        candidateIndex = index;
        break;
      }
      if (candidateIndex < 0) continue;
      final Article candidate = result.removeAt(candidateIndex);
      result.insert(slot, candidate);
      placed++;
    }
    return result;
  }

  static bool _isExplorationCandidate(Article article, ReaderSignals signals) {
    if (_followScore(article, signals.followedIds) > 0) return false;
    if (signals.readIds.contains(article.id) ||
        signals.savedIds.contains(article.id) ||
        signals.likedIds.contains(article.id)) {
      return false;
    }
    return _bestAffinityScore(article, signals.topicAffinity) <= 0 &&
        _affinityScore(signals.publisherAffinity, article.publisher.id) <= 0;
  }

  static int _followScore(Article article, Set<String> followedIds) {
    if (followedIds.isEmpty) return 0;
    int score = 0;
    if (followedIds.contains('topic:${article.categoryId}')) {
      score += PersonalizationTuning.followTopicScore;
    }
    if (followedIds.contains('publisher:${article.publisher.id}')) {
      score += PersonalizationTuning.followPublisherScore;
    }
    int tagMatches = 0;
    for (final String tag in article.tags) {
      final String lower = tag.toLowerCase();
      if (followedIds.contains(lower) &&
          (lower.startsWith('team:') || lower.startsWith('league:'))) {
        // Sports feeds emit these tags from their structured metadata.
        score += PersonalizationTuning.followTopicScore;
        continue;
      }
      if (followedIds.contains(lower) ||
          followedIds.contains('topic:$lower') ||
          followedIds.contains('city:$lower')) {
        tagMatches += PersonalizationTuning.followTagScore;
      }
    }
    return score +
        (tagMatches > PersonalizationTuning.followTagCap
            ? PersonalizationTuning.followTagCap
            : tagMatches);
  }

  /// Best category/tag affinity for a candidate. Tags are how non-category
  /// interests (city names, teams, series) reach a story.
  static int _bestAffinityScore(Article article, Map<String, double> affinity) {
    int best = _affinityScore(affinity, article.categoryId);
    for (final String tag in article.tags.take(5)) {
      final int tagScore = _affinityScore(affinity, tag.toLowerCase());
      if (tagScore > best) best = tagScore;
    }
    return best;
  }

  static int _affinityScore(Map<String, double> affinity, String key) {
    if (affinity.isEmpty) return 0;
    double peak = 0;
    for (final double candidate in affinity.values) {
      final double magnitude = candidate.abs();
      if (magnitude > peak) peak = magnitude;
    }
    if (peak <= 0) return 0;
    final double value = affinity[key] ?? 0;
    return ((value / peak) * PersonalizationTuning.affinityCeiling).round();
  }

  static int _freshnessScore(Article article, DateTime now) {
    final int hours = now.difference(article.publishedAt).inHours;
    if (hours <= 6) return PersonalizationTuning.freshSixHours;
    if (hours <= 24) return PersonalizationTuning.freshDay;
    if (hours <= 72) return PersonalizationTuning.freshThreeDays;
    if (hours <= 168) return PersonalizationTuning.freshWeek;
    return 0;
  }

  /// A tiny deterministic exploration signal: no reader data, no random state,
  /// and repeated rebuilds on the same day keep the same order.
  static int _explorationScore(Article article, DateTime now) {
    final int day = now.toUtc().difference(DateTime.utc(2026)).inDays;
    int hash = day;
    for (final int unit in article.id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash % (PersonalizationTuning.explorationMaxBonus + 1);
  }
}
