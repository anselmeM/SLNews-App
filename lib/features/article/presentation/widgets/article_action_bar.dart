import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/domain/follow_targets.dart';
import '../../../../core/domain/models/article.dart';
import '../../../../core/domain/models/app_settings.dart';
import '../../../../core/domain/models/follow_models.dart';
import '../../../../core/providers/controllers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/follow_chip.dart';
import 'translate_sheet.dart';
import '../../../../core/widgets/like_button.dart';
import '../../../../core/widgets/overflow_menu_button.dart';

/// Persistent floating action bar of the reader.
///
/// Mirrors the reference bar: a "Follow publisher" pill, the like button, the
/// dynamic text-size control (`aA`), share and the overflow menu. It floats
/// above the article body with the page gutter so the rounded container reads
/// as an overlay rather than chrome.
class ArticleActionBar extends ConsumerWidget {
  const ArticleActionBar({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FollowTarget target = publisherFollowTarget(article);
    final bool isFollowing = ref
        .watch(followingControllerProvider)
        .isFollowed(target.id);
    final bool isLiked = ref
        .watch(likesControllerProvider)
        .contains(article.id);
    final AppSettings settings = ref.watch(settingsControllerProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Material(
          color: context.colors.surface,
          elevation: 6,
          shadowColor: const Color(0x33000000),
          borderRadius: AppRadius.pillRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                FollowChip(
                  isFollowing: isFollowing,
                  dense: true,
                  followLabel: 'Follow',
                  followingLabel: 'Following',
                  onPressed: () async {
                    await ref
                        .read(followingControllerProvider.notifier)
                        .toggle(target);
                    if (!context.mounted) return;
                    _snack(
                      context,
                      ref
                              .read(followingControllerProvider)
                              .isFollowed(target.id)
                          ? 'Following ${article.publisher.name}'
                          : 'Unfollowed ${article.publisher.name}',
                    );
                  },
                ),
                const Spacer(),
                Semantics(
                  button: true,
                  label: 'Text size',
                  child: Tooltip(
                    message: 'Text size ${(settings.textScale * 100).round()}%',
                    child: InkResponse(
                      onTap: () => ref
                          .read(settingsControllerProvider.notifier)
                          .cycleTextScale(),
                      radius: 24,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'aA',
                              style: context.typography.button.copyWith(
                                color: context.colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                LikeButton(
                  isLiked: isLiked,
                  size: 22,
                  semanticLabel: 'Like ${article.title}',
                  onPressed: () => ref
                      .read(likesControllerProvider.notifier)
                      .toggle(article.id),
                ),
                Semantics(
                  button: true,
                  label: 'Translate story',
                  child: Tooltip(
                    message: 'Translate story',
                    child: InkResponse(
                      radius: 24,
                      onTap: () => openTranslation(context, article),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Icon(
                          Icons.translate,
                          size: 21,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                InkResponse(
                  radius: 24,
                  onTap: () => _share(context),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Icon(
                      Icons.ios_share,
                      size: 21,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
                OverflowMenuButton(
                  size: 22,
                  items: const <ArticleAction>[
                    ArticleAction.bookmark,
                    ArticleAction.followPublisher,
                    ArticleAction.openInBrowser,
                  ],
                  onSelected: (ArticleAction action) =>
                      _handle(context, ref, action),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    ArticleAction action,
  ) async {
    switch (action) {
      case ArticleAction.bookmark:
      case ArticleAction.removeBookmark:
        await ref.read(bookmarksControllerProvider.notifier).toggle(article.id);
        if (!context.mounted) return;
        _snack(
          context,
          ref.read(bookmarksControllerProvider).contains(article.id)
              ? 'Saved for offline reading'
              : 'Removed from saved',
        );
      case ArticleAction.followPublisher:
        final FollowTarget target = publisherFollowTarget(article);
        await ref.read(followingControllerProvider.notifier).toggle(target);
        if (!context.mounted) return;
        _snack(context, 'Updated publisher follow');
      case ArticleAction.share:
        await _share(context);
      case ArticleAction.openInBrowser:
        await _openSource(context);
    }
  }

  Future<void> _share(BuildContext context) async {
    final String text = article.sourceUrl == null
        ? article.title
        : '${article.title}\n${article.sourceUrl}';
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: article.title),
      );
    } catch (error) {
      if (!context.mounted) return;
      _snack(context, 'Sharing is unavailable on this device');
    }
  }

  Future<void> _openSource(BuildContext context) async {
    final String? url = article.sourceUrl;
    if (url == null || url.isEmpty) {
      _snack(context, 'No original link for this story');
      return;
    }
    try {
      final bool opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        _snack(context, 'Could not open the link');
      }
    } catch (error) {
      if (!context.mounted) return;
      _snack(context, 'Could not open the link');
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }
}
