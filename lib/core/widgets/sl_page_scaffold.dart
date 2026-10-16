import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'overflow_menu_button.dart';

/// Standard page chrome for the four tab roots.
///
/// Two header shapes are supported because the reference app uses both:
/// * [brandMark] set — a compact product row ("SLNews  ⋮") with the large page
///   title rendered in the scroll content (For You, News).
/// * [brandMark] null — the page title itself is the large app-bar title
///   (Sports, Following).
class SlPageScaffold extends StatelessWidget {
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

  bool get _hasBrandMark => brandMark != null && brandMark!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final Widget content = CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          pinned: true,
          floating: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: _hasBrandMark ? 48 : 64,
          automaticallyImplyLeading: false,
          titleSpacing: AppSpacing.lg,
          title: _hasBrandMark
              ? Text(
                  brandMark!,
                  style: context.typography.groupTitle.copyWith(fontSize: 21),
                )
              : (showTitleInAppBar
                    ? Text(title, style: context.typography.screenTitle)
                    : const SizedBox.shrink()),
          actions: <Widget>[
            ...actions,
            if (showOverflow)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: OverflowMenuButton(
                  size: 22,
                  items: const <ArticleAction>[
                    ArticleAction.bookmark,
                    ArticleAction.hide,
                    ArticleAction.report,
                  ],
                  onSelected: onOverflowSelected,
                ),
              ),
          ],
          bottom: bottom,
        ),
        if (body != null)
          SliverFillRemaining(hasScrollBody: false, child: body!)
        else
          ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
      ],
    );

    return Scaffold(
      backgroundColor: context.colors.canvas,
      body: onRefresh == null
          ? content
          : RefreshIndicator(onRefresh: onRefresh!, child: content),
      floatingActionButton: floatingActionButton,
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
                    maxLines: 1,
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
