import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/providers/controllers.dart';
import '../../../../core/shell/app_shell.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/article_tile.dart';
import '../../../../core/widgets/overflow_menu_button.dart';
import '../../../../core/widgets/section_header.dart';

/// "More stories" block closing the reader.
class RelatedStories extends ConsumerWidget {
  const RelatedStories({super.key, required this.articles});

  final List<Article> articles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (articles.isEmpty) return const SizedBox.shrink();
    final Set<String> liked = ref.watch(likesControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: 'More stories',
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
        ),
        for (final Article article in articles) ...<Widget>[
          ArticleTile(
            article: article,
            isLiked: liked.contains(article.id),
            thumbnailWidth: 104,
            thumbnailHeight: 96,
            onTap: () => context.openArticle(article.id),
            onLike: () => ref.read(likesControllerProvider.notifier).toggle(article.id),
            onMore: (ArticleAction action) => ref
                .read(bookmarksControllerProvider.notifier)
                .toggle(article.id),
          ),
          if (article != articles.last) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
