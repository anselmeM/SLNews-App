import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/seed/outlet_registry.dart';
import '../../../core/data/sources/feed_source.dart';
import '../../../core/domain/models/article.dart';
import '../../../core/domain/models/follow_models.dart';
import '../../../core/domain/models/publisher.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/article_tile.dart';
import '../../../core/widgets/follow_chip.dart';
import '../../../core/widgets/state_views.dart';

/// An outlet's profile (`/publisher/:id`): identity, follow and latest stories.
///
/// The header comes from the first story when the feed has one, otherwise from
/// the outlet registry, so a followed publisher with no cached stories still
/// opens as itself rather than as a bare id.
class PublisherPage extends ConsumerWidget {
  const PublisherPage({
    super.key,
    required this.publisherId,
    this.publisherLabel,
  });

  final String publisherId;

  /// Name passed by the caller; deep links fall back to the registry or id.
  final String? publisherLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Article>> stories = ref.watch(
      publisherArticlesProvider(publisherId),
    );

    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
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
          publisherLabel ?? _registry(publisherId)?.outlet ?? 'Publisher',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: stories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => ErrorStateView(
          message: "We couldn't load this publisher.",
          onRetry: () => ref.invalidate(publisherArticlesProvider(publisherId)),
        ),
        data: (List<Article> rows) {
          final Publisher publisher = _publisherFor(publisherId, rows);
          final FollowTarget target = FollowTarget(
            id: 'publisher:${publisher.id}',
            kind: FollowKind.publisher,
            label: publisher.name,
            subtitle: publisher.country,
          );
          final bool following = ref
              .watch(followingControllerProvider)
              .isFollowed(target.id);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: <Widget>[
              _PublisherHeader(
                publisher: publisher,
                following: following,
                onToggleFollow: () => ref
                    .read(followingControllerProvider.notifier)
                    .toggle(target),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (rows.isEmpty)
                const EmptyStateView(
                  title: 'No stories yet',
                  message:
                      'This publisher has no stories in your feed right now.',
                  icon: Icons.newspaper_outlined,
                )
              else ...<Widget>[
                Text('Latest stories', style: context.typography.groupTitle),
                const SizedBox(height: AppSpacing.sm),
                for (final Article article in rows) ...<Widget>[
                  ArticleTile(
                    article: article,
                    showSummary: true,
                    onTap: () => context.push(AppRoutes.articleFor(article.id)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  static FeedSourceConfig? _registry(String id) {
    for (final FeedSourceConfig config in OutletRegistry.all) {
      if (config.publisherId == id) return config;
    }
    return null;
  }

  static Publisher _publisherFor(String id, List<Article> rows) {
    if (rows.isNotEmpty) return rows.first.publisher;
    final FeedSourceConfig? config = _registry(id);
    if (config != null) {
      return Publisher(
        id: id,
        name: config.outlet,
        wordmark: config.wordmark,
        websiteUrl: config.websiteUrl,
        country: config.country,
      );
    }
    return Publisher(id: id, name: id, wordmark: id.toUpperCase());
  }
}

class _PublisherHeader extends StatelessWidget {
  const _PublisherHeader({
    required this.publisher,
    required this.following,
    required this.onToggleFollow,
  });

  final Publisher publisher;
  final bool following;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.cardRadius,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: context.colors.surfaceMuted,
                borderRadius: AppRadius.pillRadius,
              ),
              alignment: Alignment.center,
              child: Text(
                (publisher.wordmark ?? '').trim().isEmpty
                    ? publisher.name.substring(0, 1).toUpperCase()
                    : publisher.wordmark!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.overline.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    publisher.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.groupTitle,
                  ),
                  if (publisher.country.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      publisher.country,
                      style: context.typography.caption.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FollowChip(
              isFollowing: following,
              onPressed: onToggleFollow,
              followLabel: 'Follow',
              followingLabel: 'Following',
            ),
          ],
        ),
      ),
    );
  }
}
