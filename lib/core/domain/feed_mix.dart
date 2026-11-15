import 'models/article.dart';

/// Audience bucket used to keep the home feed Sierra Leone-first.
enum FeedAudience { sierraLeone, international, sports }

/// Geography/section ordering for feeds outside the Sports tab.
///
/// The app aggregates local outlets, African wires and sports-only feeds into
/// one stream. Without this split, a busy sports feed can fill the home page
/// while Sierra Leone reporting falls below the fold. The rule is deliberately
/// simple and testable: local first, international second, sport last (and only
/// a small number of sport stories outside the Sports tab).
abstract final class FeedMix {
  /// Local outlet ids, both the RSS registry ids and the API publisher ids.
  static const Set<String> _localPublisherIds = <String>{
    'sltelegraph',
    'sierraloaded',
    'awoko',
    'concordtimes',
    'politicosl',
    'standardtimes',
    'kallon',
    'footballssierraleone',
    'slnews',
    'publisher:the-sierra-leone-telegraph',
    'publisher:sierraloaded',
    'publisher:awoko-newspaper',
    'publisher:concord-times',
    'publisher:politico-sl',
    'publisher:standard-times',
    'publisher:kallons-newswire',
    'publisher:football-sierra-leone',
    'publisher:slnews',
  };

  static const Set<String> _localPublisherNames = <String>{
    'The Sierra Leone Telegraph',
    'Sierraloaded',
    'Awoko Newspaper',
    'Concord Times',
    'Politico SL',
    'Standard Times',
    "Kallon's Newswire",
    'Football Sierra Leone',
    'SLNews',
  };

  static bool isSports(Article article) =>
      article.categoryId == 'sports' ||
      article.tags.any((String tag) => tag.toLowerCase() == 'sports');

  static bool isSierraLeone(Article article) {
    if (_localPublisherIds.contains(article.publisher.id) ||
        _localPublisherNames.contains(article.publisher.name)) {
      return true;
    }
    final String text = '${article.title} ${article.summary}'.toLowerCase();
    return text.contains('sierra leone') || text.contains('freetown');
  }

  static FeedAudience audienceOf(Article article) {
    if (isSports(article)) return FeedAudience.sports;
    if (isSierraLeone(article)) return FeedAudience.sierraLeone;
    return FeedAudience.international;
  }

  static int priorityOf(Article article) => switch (audienceOf(article)) {
    FeedAudience.sierraLeone => 0,
    FeedAudience.international => 1,
    FeedAudience.sports => 2,
  };

  /// Comparator: Sierra Leone first, then international, then sports; within a
  /// bucket newest first unless [within] decides otherwise.
  static int compare(
    Article a,
    Article b, {
    int Function(Article, Article)? within,
  }) {
    final int byAudience = priorityOf(a).compareTo(priorityOf(b));
    if (byAudience != 0) return byAudience;
    final int custom = within?.call(a, b) ?? 0;
    if (custom != 0) return custom;
    return b.publishedAt.compareTo(a.publishedAt);
  }

  /// Newest sports stories, capped for the non-sports surfaces.
  static List<Article> limitedSports(
    Iterable<Article> articles, {
    int limit = 2,
  }) {
    final List<Article> sports =
        articles.where(isSports).toList(growable: false)..sort(
          (Article a, Article b) => b.publishedAt.compareTo(a.publishedAt),
        );
    return sports.take(limit).toList(growable: false);
  }
}
