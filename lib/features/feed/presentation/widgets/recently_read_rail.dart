import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/providers/reading_history_provider.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/article_grid_tile.dart';
import '../../../../core/widgets/section_header.dart';

/// "Recently read": a compact rail of the stories this device opened last.
///
/// Sits below the main feed so it never competes with fresh news, but is one tap
/// away when a reader wants to finish something they started.
class RecentlyReadRail extends ConsumerWidget {
  const RecentlyReadRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Article> articles =
        ref.watch(recentlyReadArticlesProvider).value ?? const <Article>[];
    if (articles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(left: AppSpacing.lg, top: AppSpacing.md),
          child: SectionHeader(title: 'Recently read'),
        ),
        SizedBox(
          height: 218,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: articles.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final Article article = articles[index];
              return SizedBox(
                width: 190,
                child: ArticleGridTile(
                  article: article,
                  maxTitleLines: 2,
                  onTap: () => context.push(AppRoutes.articleFor(article.id)),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.lg,
            top: AppSpacing.xs,
          ),
          child: Text(
            'Only on this device',
            style: context.typography.caption.copyWith(
              color: context.colors.onSurfaceFaint,
            ),
          ),
        ),
      ],
    );
  }
}
