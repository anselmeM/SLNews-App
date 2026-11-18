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
///
/// Locality comes from the publisher's own [Publisher.country], which the outlet
/// registry supplies, rather than a hand-maintained list of ids and names: the
/// old lists mixed two id formats (`awoko` and `awoko-newspaper`) and a typo in
/// one of them silently mis-ranked an outlet. Keyword matching is now only the
/// fallback for publishers whose country is unknown.
abstract final class FeedMix {
  static const String _sierraLeone = 'sierra leone';

  static bool isSports(Article article) =>
      article.categoryId == 'sports' ||
      article.tags.any((String tag) => tag.toLowerCase() == 'sports');

  static bool isSierraLeone(Article article) {
    final String country = article.publisher.country.trim().toLowerCase();
    if (country == _sierraLeone) return true;
    // A known foreign outlet still belongs in the local bucket when the story
    // itself is about Sierra Leone (wires covering Freetown). The headline is
    // the stronger signal — a summary can mention the country in passing.
    if (country.isNotEmpty) return _mentions(article.title);
    // Unknown provenance: the scraper API names the outlet but sends no
    // country, so the story text is the only signal available.
    return _mentions('${article.title} ${article.summary}');
  }

  static bool _mentions(String text) {
    final String lower = text.toLowerCase();
    return lower.contains(_sierraLeone) || lower.contains('freetown');
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
