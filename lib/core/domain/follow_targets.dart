import 'models/article.dart';
import 'models/follow_models.dart';

/// Builds the follow target that represents an article's publisher.
///
/// Kept next to the models rather than in a screen so the reader's Follow pill
/// and the shared article-action menu create exactly the same subscription id.
FollowTarget publisherFollowTarget(Article article) => FollowTarget(
  id: 'publisher:${article.publisher.id}',
  kind: FollowKind.publisher,
  label: article.publisher.name,
  subtitle: article.publisher.country,
);
