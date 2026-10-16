import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/article.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/article_tile.dart';
import '../../../core/widgets/overflow_menu_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../feed/presentation/widgets/article_actions.dart';
import 'saved_stories_provider.dart';

/// Saved stories — the offline reading list reached from the app-bar menu.
///
/// Everything rendered here comes from local state ([savedStoriesProvider]
/// over the bookmarked ids), so the page renders identically with no network.
class SavedStoriesPage extends ConsumerWidget {
  const SavedStoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Article>> saved = ref.watch(savedStoriesProvider);

    return Scaffold(
      backgroundColor: context.colors.canvas,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: context.colors.canvas,
            surfaceTintColor: Colors.transparent,
            forceMaterialTransparency: true,
            titleSpacing: 0,
            title: Text('Saved stories', style: context.typography.screenTitle),
          ),
          saved.when(
            data: (List<Article> articles) => articles.isEmpty
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateView(
                      title: 'Nothing saved yet',
                      message: 'Tap Save on any story to read it offline.',
                    ),
                  )
                : _SavedSliver(articles: articles),
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object error, StackTrace stack) => SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorStateView(onRetry: () => ref.invalidate(savedStoriesProvider)),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
        ],
      ),
    );
  }
}

/// The saved rows: a tile per article with an explicit remove affordance.
class _SavedSliver extends ConsumerWidget {
  const _SavedSliver({required this.articles});

  final List<Article> articles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverList.separated(
      itemCount: articles.length,
      separatorBuilder: (BuildContext context, int index) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int index) => _SavedRow(article: articles[index]),
    );
  }
}

/// One saved story: the standard feed card with a one-tap remove control.
class _SavedRow extends ConsumerWidget {
  const _SavedRow({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: AppSpacing.page,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: ArticleTile(
              article: article,
              showThumbnail: false,
              onTap: () => context.push(AppRoutes.articleFor(article.id)),
              onMore: (ArticleAction action) => handleArticleAction(context, ref, article, action),
            ),
          ),
          IconButton(
            // The messenger is resolved while the context is still synchronous,
            // so the async removal never touches a BuildContext.
            onPressed: () => _remove(ScaffoldMessenger.of(context), ref, article),
            tooltip: 'Remove from saved',
            icon: Icon(Icons.bookmark_remove_outlined, color: context.colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// Mirrors the shared bookmark handler for the one-tap remove control.
  Future<void> _remove(
    ScaffoldMessengerState messenger,
    WidgetRef ref,
    Article article,
  ) async {
    try {
      await ref.read(bookmarksControllerProvider.notifier).toggle(article.id);
    } on Object {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't update your saved stories")));
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Removed from saved')));
  }
}
