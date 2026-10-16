import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/article.dart';
import '../../../core/domain/models/follow_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/html_content.dart';
import '../../../core/widgets/state_views.dart';
import 'widgets/article_action_bar.dart';
import 'widgets/article_header.dart';
import 'widgets/article_hero_media.dart';
import 'widgets/related_stories.dart';

/// The dedicated article reader (`/article/:id`).
///
/// Layout follows the CBC-style reference screen: publisher attribution and
/// headline at the top, hero media with caption, then the body, finished by the
/// persistent floating action bar (follow publisher, like, `aA`, share, menu).
class ArticlePage extends ConsumerWidget {
  const ArticlePage({super.key, required this.articleId});

  final String articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Article?> article = ref.watch(articleProvider(articleId));

    return Scaffold(
      backgroundColor: context.colors.canvas,
      body: article.when(
        loading: () => const _ReaderSkeleton(),
        error: (Object error, StackTrace stackTrace) => SafeArea(
          child: ErrorStateView(
            message: "We couldn't open this story.",
            onRetry: () => ref.invalidate(articleProvider(articleId)),
          ),
        ),
        data: (Article? story) {
          if (story == null) {
            return SafeArea(
              child: EmptyStateView(
                title: 'Story unavailable',
                message: 'This story is no longer in your saved feed.',
                actionLabel: 'Back',
                onAction: () => context.pop(),
                icon: Icons.article_outlined,
              ),
            );
          }
          return _ReaderBody(article: story);
        },
      ),
      bottomNavigationBar: article.value == null
          ? null
          : ArticleActionBar(article: article.value!),
    );
  }
}

class _ReaderBody extends ConsumerWidget {
  const _ReaderBody({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Article> related = ref
        .watch(categoryFeedProvider(article.categoryId))
        .value
        ?.where((Article candidate) => candidate.id != article.id)
        .take(4)
        .toList(growable: false) ??
        const <Article>[];

    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          pinned: true,
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () => context.pop(),
          ),
          title: Text(
            article.publisher.mark,
            style: context.typography.meta.copyWith(color: context.colors.onSurfaceVariant),
          ),
          centerTitle: true,
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.bookmark_border),
              tooltip: 'Save story',
              onPressed: () {
                ref.read(bookmarksControllerProvider.notifier).toggle(article.id);
                _showSnack(context, ref.read(bookmarksControllerProvider).contains(article.id) ? 'Saved' : 'Removed from saved');
              },
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
        SliverPadding(
          padding: AppSpacing.page,
          sliver: SliverList.list(
            children: <Widget>[
              ArticleHeader(article: article),
              const SizedBox(height: AppSpacing.lg),
              ArticleHeroMedia(article: article),
              const SizedBox(height: AppSpacing.xl),
              // Shown only when the outlet did not simply repeat the standfirst
              // as the body's opening paragraph.
              if (article.summary.isNotEmpty &&
                  !HtmlBlocks.opensWith(article.bodyHtml, article.summary)) ...<Widget>[
                Text(article.summary, style: context.typography.lead),
                const SizedBox(height: AppSpacing.lg),
              ],
              HtmlContent(html: article.bodyHtml),
              if (article.tags.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final String tag in article.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs + 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceMuted,
                          borderRadius: AppRadius.pillRadius,
                        ),
                        child: Text('#$tag', style: context.typography.caption),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              RelatedStories(articles: related),
              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ],
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }
}

/// Reader placeholder that reserves the real layout's geometry.
class _ReaderSkeleton extends StatelessWidget {
  const _ReaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

/// Builds the follow target that represents a publisher.
FollowTarget publisherFollowTarget(Article article) => FollowTarget(
  id: 'publisher:${article.publisher.id}',
  kind: FollowKind.publisher,
  label: article.publisher.name,
  subtitle: article.publisher.country,
);
