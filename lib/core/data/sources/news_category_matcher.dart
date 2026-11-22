import '../../domain/models/news_category.dart';

/// Strong category words used when a feed exposes free-form labels or only a
/// headline. The first recognised category wins.
const Map<String, String> _categoryAliases = <String, String>{
  'politics': 'politics',
  'political': 'politics',
  'government': 'politics',
  'governance': 'politics',
  'parliament': 'politics',
  'parliamentary': 'politics',
  'president': 'politics',
  'presidential': 'politics',
  'minister': 'politics',
  'ministry': 'politics',
  'election': 'politics',
  'elections': 'politics',
  'policy': 'politics',
  'law': 'politics',
  'court': 'politics',
  'council': 'politics',
  'business': 'business',
  'economy': 'business',
  'economic': 'business',
  'finance': 'business',
  'financial': 'business',
  'bank': 'business',
  'market': 'business',
  'markets': 'business',
  'trade': 'business',
  'inflation': 'business',
  'tax': 'business',
  'budget': 'business',
  'investment': 'business',
  'exports': 'business',
  'imports': 'business',
  'health': 'health',
  'healthcare': 'health',
  'medicine': 'health',
  'medical': 'health',
  'hospital': 'health',
  'clinic': 'health',
  'malaria': 'health',
  'vaccine': 'health',
  'disease': 'health',
  'outbreak': 'health',
  'education': 'education',
  'school': 'education',
  'schools': 'education',
  'teacher': 'education',
  'teachers': 'education',
  'university': 'education',
  'college': 'education',
  'exam': 'education',
  'exams': 'education',
  'students': 'education',
  'mining': 'mining',
  'miner': 'mining',
  'miners': 'mining',
  'mineral': 'mining',
  'minerals': 'mining',
  'diamond': 'mining',
  'diamonds': 'mining',
  'rutile': 'mining',
  'bauxite': 'mining',
  'iron ore': 'mining',
  'gold': 'mining',
  'culture': 'culture',
  'arts': 'culture',
  'art': 'culture',
  'entertainment': 'culture',
  'festival': 'culture',
  'festivals': 'culture',
  'heritage': 'culture',
  'theatre': 'culture',
  'theater': 'culture',
  'film': 'culture',
  'cinema': 'culture',
  'music': 'music',
  'musician': 'music',
  'musicians': 'music',
  'album': 'music',
  'concert': 'music',
  'song': 'music',
  'songs': 'music',
  'cars': 'cars',
  'car': 'cars',
  'vehicles': 'cars',
  'vehicle': 'cars',
  'automotive': 'cars',
  'tech': 'tech',
  'technology': 'tech',
  'digital': 'tech',
  'internet': 'tech',
  'telecom': 'tech',
  'telecommunications': 'tech',
  'mobile money': 'tech',
  'ict': 'tech',
  'artificial intelligence': 'tech',
  'startup': 'tech',
  'world': 'world',
  'international': 'world',
  'global': 'world',
  'sports': 'sports',
  'sport': 'sports',
  'football': 'sports',
  'soccer': 'sports',
  'volleyball': 'sports',
  'formula 1': 'sports',
  'f1': 'sports',
  'darts': 'sports',
  'wrestling': 'sports',
  'judo': 'sports',
  'swimming': 'sports',
  'para': 'sports',
  'commonwealth': 'sports',
  'wafu': 'sports',
  'league': 'sports',
  'basketball': 'sports',
  'athletics': 'sports',
  'boxing': 'sports',
  'cricket': 'sports',
  'rugby': 'sports',
  'tennis': 'sports',
  'golf': 'sports',
  'cycling': 'sports',
  'olympic': 'sports',
  'olympics': 'sports',
  'afcon': 'sports',
  'leone stars': 'sports',
  'bo rangers': 'sports',
  'mighty blackpool': 'sports',
  'premier league': 'sports',
  'sierra leone premier league': 'sports',
  'fifa': 'sports',
  'caf': 'sports',
};

/// The curated category a free-form label belongs to, or `null`.
String? categoryIdForTerm(String term) {
  final String needle = term.toLowerCase().trim();
  if (needle.isEmpty) return null;
  final String? alias = _categoryAliases[needle];
  if (alias != null) return alias;
  for (final NewsCategory category in NewsCategories.all) {
    if (category.id.toLowerCase() == needle) return category.id;
    if (category.label.toLowerCase() == needle) return category.id;
  }
  return null;
}

/// Splits labels such as `Politics & Law` or `Business, Finance` into parts.
List<String> splitCategoryLabel(String raw) {
  return <String>[
    for (final String chunk in raw.split(RegExp(r'[&,;]| / |/|\|')))
      if (chunk.trim().isNotEmpty) chunk.trim(),
  ];
}

/// Returns the first curated category found in [terms].
///
/// Terms may be category labels, tags or a headline. Searching the title as a
/// fallback is intentional: several Sierra Leone outlets publish one combined
/// feed and do not tag individual posts.
String? categoryIdForTerms(Iterable<String> terms) {
  // Explicit labels/tags win over headline guesses.
  for (final String term in terms) {
    for (final String part in splitCategoryLabel(term)) {
      final String? id = categoryIdForTerm(part);
      if (id != null) return id;
    }
  }
  for (final String term in terms) {
    final String lower = term.toLowerCase();
    for (final String phrase in <String>[
      'iron ore',
      'mobile money',
      'artificial intelligence',
      'leone stars',
      'bo rangers',
      'mighty blackpool',
      'premier league',
    ]) {
      if (lower.contains(phrase)) {
        return _categoryAliases[phrase] ?? categoryIdForTerm(phrase);
      }
    }
    final List<String> words = lower
        .split(RegExp(r'[^a-z0-9]+'))
        .where((String word) => word.length > 2)
        .toList(growable: false);
    for (final String word in words) {
      final String? id = categoryIdForTerm(word);
      if (id != null) return id;
    }
  }
  return null;
}
