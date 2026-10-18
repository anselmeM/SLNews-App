import 'package:flutter/material.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/pressable_ink_well.dart';
import '../../../../core/widgets/publisher_mark.dart';
import '../../../../core/widgets/sl_network_image.dart';

/// "Trending now": the reference's numbered list of the day's most-read stories.
///
/// Ranks are large numerals down the left, publisher mark and headline in the
/// middle, thumbnail on the right. Ranking is computed from what the feed knows
/// (breaking first, image-bearing and newer next) since the wire carries no
/// read counts; the ordering is deterministic so tests and goldens are stable.
class TrendingNow extends StatelessWidget {
  const TrendingNow({
    super.key,
    required this.articles,
    required this.onOpen,
    this.limit = 3,
  });

  final List<Article> articles;
  final ValueChanged<Article> onOpen;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final List<Article> ranked = trendingArticles(articles, limit: limit);
    if (ranked.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int index = 0; index < ranked.length; index++)
          PressableInkWell(
            onTap: () => onOpen(ranked[index]),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${index + 1}',
                      style: context.typography.sectionTitle.copyWith(
                        fontWeight: FontWeight.w300,
                        color: context.colors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        PublisherMark(
                          publisher: ranked[index].publisher,
                          logoHeight: 15,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          ranked[index].title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.cardTitle.copyWith(
                            fontSize: 16,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if ((ranked[index].imageUrl ?? '')
                      .trim()
                      .isNotEmpty) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: AppRadius.imageRadius,
                      child: SizedBox(
                        width: 92,
                        height: 62,
                        child: SlNetworkImage(
                          url: ranked[index].imageUrl ?? '',
                          placeholderLabel: ranked[index].publisher.mark,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Ranks [articles] for the Trending section.
///
/// Score: breaking stories first, then stories with an image, then recency.
/// Ties break on publish time so the list never reorders between rebuilds.
List<Article> trendingArticles(List<Article> articles, {int limit = 3}) {
  final List<Article> ranked = List<Article>.of(articles);
  ranked.sort((Article a, Article b) {
    final int byScore = _score(b).compareTo(_score(a));
    if (byScore != 0) return byScore;
    return b.publishedAt.compareTo(a.publishedAt);
  });
  return ranked.take(limit).toList(growable: false);
}

int _score(Article article) {
  int score = 0;
  if (article.isBreaking) score += 4;
  if (article.isLive) score += 2;
  if ((article.imageUrl ?? '').trim().isNotEmpty) score += 1;
  return score;
}
