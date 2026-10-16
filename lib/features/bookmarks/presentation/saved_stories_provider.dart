import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/models/article.dart';
import '../../../core/domain/repositories/article_repository.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/controllers.dart';

/// Resolves the bookmarked ids into full [Article]s.
///
/// Declared here (not in `lib/core/providers/`) because saved stories are owned
/// by this feature. It deliberately reads local state only: the repository
/// answers from its cache, so Saved stories works with zero network.
final FutureProvider<List<Article>>
savedStoriesProvider = FutureProvider<List<Article>>((Ref ref) async {
  final Set<String> ids = ref.watch(bookmarksControllerProvider);
  if (ids.isEmpty) return const <Article>[];

  final ArticleRepository repository = ref.read(articleRepositoryProvider);
  final List<Article> resolved = <Article>[];
  for (final String id in ids) {
    final Article? article = await repository.byId(id);
    if (article != null) resolved.add(article);
  }
  // A `Set` carries no meaningful display order, so the saved list is always
  // newest-first rather than in the order ids happened to be saved.
  resolved.sort(
    (Article a, Article b) => b.publishedAt.compareTo(a.publishedAt),
  );
  return resolved;
}, name: 'savedStories');
