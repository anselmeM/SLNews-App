/// Editorial rule for deciding whether a story deserves the breaking banner.
///
/// A feed label alone is not enough: outlets tag routine stories "Breaking
/// News", and seed/demo content can carry flags too. This policy scores the
/// actual title/summary and requires a real impact signal before anything is
/// promoted.
library;

import 'models/article.dart';

/// Result of scoring one story.
class BreakingAssessment {
  const BreakingAssessment({
    required this.isBreaking,
    required this.score,
    required this.reasons,
  });

  final bool isBreaking;
  final int score;
  final List<String> reasons;

  @override
  String toString() =>
      'BreakingAssessment(isBreaking: $isBreaking, score: $score, '
      'reasons: ${reasons.join(", ")})';
}

/// Pure, deterministic breaking-news classification.
abstract final class BreakingNewsPolicy {
  /// Minimum score for promotion.
  static const int threshold = 5;

  /// Categories where a verified urgent label can stand on its own.
  static const Set<String> hardNewsCategories = <String>{
    'politics',
    'world',
    'health',
    'business',
    'mining',
  };

  /// Words that signal an unfolding situation.
  static const List<String> _urgencyTerms = <String>[
    'breaking',
    'just in',
    'developing',
    'urgent',
    'news alert',
    'live update',
  ];

  /// Impact/severity terms, with the weight each contributes.
  static const Map<String, int> _impactTerms = <String, int>{
    'dead': 3,
    'death': 3,
    'died': 3,
    'killed': 3,
    'kills': 3,
    'fatal': 3,
    'casualties': 3,
    'explosion': 3,
    'blast': 3,
    'fire': 3,
    'flood': 3,
    'flooding': 3,
    'landslide': 3,
    'earthquake': 3,
    'collapse': 3,
    'derail': 3,
    'capsized': 3,
    'sinking': 3,
    'state of emergency': 4,
    'curfew': 3,
    'coup': 4,
    'martial law': 4,
    'outbreak': 3,
    'epidemic': 3,
    'pandemic': 3,
    'cholera': 3,
    'ebola': 3,
    'measles': 2,
    'crash': 2,
    'accident': 2,
    'ferry': 2,
    'rescue': 2,
    'missing': 2,
    'shutdown': 2,
    'election result': 2,
    'election results': 2,
    'inauguration': 2,
    'resignation': 2,
    'impeachment': 3,
    'court ruling': 2,
    'supreme court': 2,
    'verdict': 2,
    'sacked': 2,
    'suspends': 2,
    'bans': 2,
    'riot': 2,
    'strike': 1,
    'protest': 1,
    'arrest': 1,
    'detained': 1,
  };

  /// Stories whose headline marks them as opinion/feature are not breaking.
  static const List<String> _nonNewsTerms = <String>[
    'opinion',
    'analysis',
    'explainer',
    'review',
    'how to',
    'photos:',
    'editorial',
    'commentary',
    'recipe',
    'horoscope',
  ];

  /// Scores [title]/[summary] for a possible breaking promotion.
  static BreakingAssessment assess({
    required String title,
    required String summary,
    required String categoryId,
    Iterable<String> tags = const <String>[],
    DateTime? publishedAt,
    bool isWire = false,
    bool editorFlagged = false,
    DateTime? now,
  }) {
    final String headline = title.toLowerCase();
    final String body = '$title $summary ${tags.join(' ')}'.toLowerCase();
    final List<String> reasons = <String>[];
    int score = 0;

    final bool urgent = _containsAny(headline, _urgencyTerms);
    if (urgent) {
      score += 2;
      reasons.add('urgency');
    }

    int impact = 0;
    final Set<String> matchedImpact = <String>{};
    for (final MapEntry<String, int> entry in _impactTerms.entries) {
      if (_containsTerm(body, entry.key)) {
        impact += entry.value;
        matchedImpact.add(entry.key);
      }
    }
    if (impact > 0) {
      final int capped = impact > 6 ? 6 : impact;
      score += capped;
      reasons.addAll(matchedImpact);
    }

    if (hardNewsCategories.contains(categoryId)) {
      score += 1;
      reasons.add('hard-news');
    }

    final DateTime reference = now ?? DateTime.now();
    final DateTime? published = publishedAt;
    if (published != null) {
      final Duration age = reference.difference(published);
      if (age <= const Duration(hours: 2)) {
        score += 2;
        reasons.add('fresh');
      } else if (age <= const Duration(hours: 6)) {
        score += 1;
        reasons.add('recent');
      } else if (age > const Duration(hours: 24)) {
        score -= 3;
        reasons.add('stale');
      }
    }

    if (isWire) {
      score += 1;
      reasons.add('wire');
    }
    if (editorFlagged) {
      score += 1;
      reasons.add('editor-flag');
    }
    if (_containsAny(headline, _nonNewsTerms)) {
      score -= 2;
      reasons.add('non-news');
    }

    final bool qualifies =
        score >= threshold &&
        (impact >= 3 || (urgent && hardNewsCategories.contains(categoryId)));
    return BreakingAssessment(
      isBreaking: qualifies,
      score: score,
      reasons: List<String>.unmodifiable(reasons),
    );
  }

  /// Re-evaluates an already-materialised article, including cached rows that
  /// were stored before this policy existed.
  static Article normalize(Article article, {DateTime? now}) {
    final BreakingAssessment result = assess(
      title: article.title,
      summary: article.summary,
      categoryId: article.categoryId,
      tags: article.tags,
      publishedAt: article.publishedAt,
      isWire: article.publisher.isWire,
      editorFlagged: article.isBreaking,
      now: now,
    );
    return result.isBreaking == article.isBreaking
        ? article
        : article.copyWith(isBreaking: result.isBreaking);
  }

  static bool _containsAny(String text, Iterable<String> terms) {
    for (final String term in terms) {
      if (_containsTerm(text, term)) return true;
    }
    return false;
  }

  static bool _containsTerm(String text, String term) {
    return RegExp(
      '(^|[^a-z0-9])${RegExp.escape(term)}([^a-z0-9]|\$)',
      caseSensitive: false,
    ).hasMatch(text);
  }
}
