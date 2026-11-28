import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:slnews_mobile/core/widgets/scroll_to_top_state_mixin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ads/sponsorship_launcher.dart';
import '../../../core/domain/models/ad_placement.dart';
import '../../../core/domain/models/ad_unit.dart';
import '../../../core/domain/analytics/aggregate_feed_metrics.dart';
import '../../../core/domain/models/article.dart';
import '../../../core/providers/aggregate_metrics.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/providers/personalization_profile.dart';
import '../../../core/providers/reading_history_provider.dart';
import '../../../core/tts/tts_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/html_content.dart';
import '../../../core/widgets/publisher_mark.dart';
import '../../../core/widgets/tracked_ad_card.dart';
import '../../../core/widgets/scroll_to_top_button.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/article_web_mode.dart';
import 'widgets/article_action_bar.dart';
import 'widgets/reading_progress_bar.dart';
import 'widgets/article_header.dart';
import 'widgets/article_hero_media.dart';
import 'widgets/related_stories.dart';

part 'article_reader_body.dart';
part 'article_reader_skeleton.dart';

int _profileGenerationOf(WidgetRef ref) {
  try {
    return ref.read(personalizationProfileProvider.notifier).generation;
  } catch (_) {
    return 0;
  }
}

bool _personalizationEnabled(WidgetRef ref) {
  try {
    return ref.read(settingsControllerProvider).personalizeFeed;
  } catch (_) {
    return true;
  }
}

bool _personalizationEnabledContainer(ProviderContainer container) {
  try {
    return container.read(settingsControllerProvider).personalizeFeed;
  } catch (_) {
    return true;
  }
}

String _accountKey(WidgetRef ref) {
  try {
    return ref.read(activeAccountKeyProvider);
  } catch (_) {
    return 'anonymous';
  }
}

/// The dedicated article reader (`/article/:id`).
///
/// Layout follows the CBC-style reference screen: the outlet's wordmark in the
/// bar, attribution and headline at the top, hero media with caption, then the
/// body, finished by the persistent floating action bar (follow publisher, `aA`,
/// like, translate, share, menu).
class ArticlePage extends ConsumerWidget {
  const ArticlePage({super.key, required this.articleId, this.initialProgress});

  final String articleId;

  /// Last local reading position, used by the Continue reading rail.
  final double? initialProgress;

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
          final String ownerAccount = _accountKey(ref);
          final List<String> history = ref.read(readingHistoryProvider);
          if (history.isEmpty || history.first != story.id) {
            // Record after the frame: the notifier writes preferences, which
            // must not happen during build. Keep the account captured at open.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref
                  .read(readingHistoryProvider.notifier)
                  .record(story.id, accountKey: ownerAccount);
            });
          }
          return _ReaderBody(article: story, initialProgress: initialProgress);
        },
      ),
      bottomNavigationBar: article.value == null
          ? null
          : FadeSlideIn(
              // Rises the short distance from the edge, once, when the reader
              // has something to act on.
              offset: -10,
              child: ArticleActionBar(article: article.value!),
            ),
    );
  }
}
