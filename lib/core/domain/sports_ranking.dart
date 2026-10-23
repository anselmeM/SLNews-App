import 'models/article.dart';

/// Sierra Leone publishers whose sport coverage leads the Sports tab.
///
/// Publisher ids are stable slugs from the outlet registry; seed articles reuse
/// them, so this works for both live feeds and the bundled fallback.
const Set<String> sierraLeonePublishers = <String>{
  'sltelegraph',
  'sierraloaded',
  'awoko',
  'concordtimes',
  'politicosl',
  'footballsierraleone',
  'slnews',
};

/// Orders sports stories local-first, then newest-first within each group.
///
/// Pure and stable: the caller caps the list after ranking, so a local story is
/// never dropped just because international wires published more that hour.
List<Article> rankSportsStories(List<Article> stories) {
  final List<Article> ranked = List<Article>.of(stories);
  bool isLocal(Article article) =>
      sierraLeonePublishers.contains(article.publisher.id);
  ranked.sort((Article a, Article b) {
    final int local = (isLocal(a) ? 0 : 1).compareTo(isLocal(b) ? 0 : 1);
    if (local != 0) return local;
    return b.publishedAt.compareTo(a.publishedAt);
  });
  return ranked;
}
