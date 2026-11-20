import 'package:flutter/material.dart';

import 'scroll_to_top_state_mixin.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'overflow_menu_button.dart';
import 'page_menu_button.dart';
import 'scroll_to_top_button.dart';
import 'state_views.dart';

import '../providers/offline_status.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Standard page chrome for the four tab roots.
///
/// Two header shapes are supported because the reference app uses both:
/// * [brandMark] set — a compact product row ("SLNews  ⋮") with the large page
///   title rendered in the scroll content (For You, News).
/// * [brandMark] null — the page title itself is the large app-bar title
///   (Sports, Following).
///
/// It also owns the reference screen's circular "back to top" button, which
/// appears once the reader has scrolled past the first screenful.
class SlPageScaffold extends ConsumerStatefulWidget {
  const SlPageScaffold({
    super.key,
    required this.title,
    this.brandMark,
    this.actions = const <Widget>[],
    this.slivers = const <Widget>[],
    this.body,
    this.bottom,
    this.showOverflow = true,
    this.onOverflowSelected,
    this.onRefresh,
    this.floatingActionButton,
    this.showTitleInAppBar = true,
    this.showScrollToTop = true,
    this.showOfflineBanner = true,
  });

  final String title;

  /// Small product mark, e.g. "SLNews". When set, [title] must be rendered in
  /// the content via [SlPageTitle].
  final String? brandMark;

  final List<Widget> actions;
  final List<Widget> slivers;

  /// Alternative to [slivers] for simple, non-sliver bodies.
  final Widget? body;

  /// Pinned widget under the app bar, e.g. the category pill strip.
  final PreferredSizeWidget? bottom;

  final bool showOverflow;
  final ValueChanged<ArticleAction>? onOverflowSelected;
  final Future<void> Function()? onRefresh;
  final Widget? floatingActionButton;

  /// When false the title is omitted from the app bar (the content renders it).
  final bool showTitleInAppBar;

  /// Shows the back-to-top affordance once [scrollToTopThreshold] is passed.
  final bool showScrollToTop;

  /// Shows the "offline - showing saved stories" banner above the content.
  final bool showOfflineBanner;

  /// Distance scrolled before the back-to-top button appears.
  static const double scrollToTopThreshold = ScrollToTopButton.threshold;

  @override
  ConsumerState<SlPageScaffold> createState() => _SlPageScaffoldState();
}

class _SlPageScaffoldState extends ConsumerState<SlPageScaffold>
    with ScrollToTopStateMixin<SlPageScaffold> {
  @override
  double get scrollToTopThreshold => SlPageScaffold.scrollToTopThreshold;

  bool get _hasBrandMark {
    final String? mark = widget.brandMark;
    return mark != null && mark.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final OfflineStatus offline = widget.showOfflineBanner
        ? readOfflineStatus(ref)
        : const OfflineStatus(isOffline: false);
    final Widget content = CustomScrollView(
      controller: scrollController,
      slivers: <Widget>[
        SliverAppBar(
          pinned: true,
          floating: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: _hasBrandMark ? 56 : 64,
          automaticallyImplyLeading: false,
          titleSpacing: AppSpacing.xl,
          title: _hasBrandMark
              ? Text(
                  widget.brandMark!,
                  style: context.typography.groupTitle.copyWith(fontSize: 21),
                )
              : (widget.showTitleInAppBar
                    ? Text(widget.title, style: context.typography.screenTitle)
                    : const SizedBox.shrink()),
          actions: <Widget>[
            ...widget.actions,
            // Two menu shapes, because the reference app uses both: pages that
            // need story-level actions pass `onOverflowSelected` (the article
            // menu), every other page gets the page menu — Settings and Notices.
            if (widget.showOverflow)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: widget.onOverflowSelected != null
                    ? OverflowMenuButton(
                        size: 22,
                        items: const <ArticleAction>[
                          ArticleAction.bookmark,
                          ArticleAction.share,
                          ArticleAction.openInBrowser,
                          ArticleAction.followPublisher,
                        ],
                        onSelected: widget.onOverflowSelected,
                      )
                    : const PageMenuButton(),
              ),
          ],
          bottom: widget.bottom,
        ),
        if (offline.isOffline)
          SliverToBoxAdapter(
            child: OfflineBanner(
              isOffline: true,
              lastSyncedAt: offline.lastSyncedAt,
            ),
          ),
        if (widget.body != null)
          SliverFillRemaining(hasScrollBody: false, child: widget.body!)
        else
          ...widget.slivers,
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
      ],
    );

    final Widget? fab =
        widget.floatingActionButton ??
        (widget.showScrollToTop && showScrollToTopButton
            ? ScrollToTopButton(onPressed: scrollToTop)
            : null);

    return Scaffold(
      backgroundColor: context.colors.canvas,
      body: widget.onRefresh == null
          ? content
          : RefreshIndicator(onRefresh: widget.onRefresh!, child: content),
      floatingActionButton: fab,
    );
  }
}

/// Large in-content page title, e.g. "Top stories ›".
class SlPageTitle extends StatelessWidget {
  const SlPageTitle({
    super.key,
    required this.title,
    this.onTap,
    this.trailing,
  });

  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        children: <Widget>[
          // The title owns the row: it is laid out against the whole width and
          // only ellipsizes when a trailing widget actually needs the space.
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.screenTitle,
                  ),
                ),
                if (onTap != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.xs),
                  GestureDetector(
                    onTap: onTap,
                    child: Icon(
                      Icons.chevron_right,
                      size: 30,
                      color: context.colors.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
