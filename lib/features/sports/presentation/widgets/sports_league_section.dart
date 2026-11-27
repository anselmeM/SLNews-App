import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/domain/models/sports_models.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/widgets/article_tile.dart';
import '../../../../core/widgets/publisher_mark.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/overflow_menu_button.dart';
import '../../../../core/widgets/sl_network_image.dart';
import '../../../feed/presentation/widgets/article_actions.dart';
import 'league_look.dart';
import 'score_card.dart';

/// One Samsung-style league block in the Sports feed.
///
/// A coloured header with the league name and a Follow pill, the league's score
/// cards, a full-bleed hero story, compact stories and a "More … stories" link —
/// matching the reference Sports tab.
class SportsLeagueSection extends ConsumerWidget {
  const SportsLeagueSection({
    super.key,
    required this.leagueLabel,
    required this.leagueId,
    required this.games,
    this.preferredArticles = const <Article>[],
    required this.isFollowing,
    required this.onToggleFollow,
    required this.onArticleTap,
    required this.onMore,
    required this.onGameTap,
    required this.onLeagueTap,
  });

  final String leagueLabel;

  /// League slug (`nba`, `nfl`, `epl`, ...) for the lazy news feed.
  final String leagueId;
  final List<GameScore> games;

  /// Followed-team stories take precedence over the league feed.
  final List<Article> preferredArticles;
  final bool isFollowing;
  final VoidCallback onToggleFollow;
  final ValueChanged<Article> onArticleTap;
  final VoidCallback onMore;
  final ValueChanged<GameScore> onGameTap;
  final VoidCallback onLeagueTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched here, not in the page: a league block only starts its feed request
    // when SliverList.builder builds it near the viewport.
    final AsyncValue<List<Article>> leagueNews = ref.watch(
      leagueNewsProvider('league:$leagueId'),
    );
    final List<Article> feed = leagueNews.asData?.value ?? const <Article>[];
    // Only authoritative league sources feed this block: its own league feed,
    // or the followed NBA team's league-scoped news. There is deliberately no
    // generic-sports fallback — an empty block is better than a wrong league.
    final List<Article> stories = preferredArticles.isNotEmpty
        ? preferredArticles
        : feed;
    final List<Article> shownStories = stories.take(4).toList(growable: false);

    // A section with neither a fixture nor a story is noise: the catalogue
    // includes off-season leagues, and their feeds may legitimately be empty.
    if (games.isEmpty && shownStories.isEmpty) {
      // A league whose feed is still loading gets a placeholder instead of
      // popping into the page later; an empty result stays hidden.
      // Only followed leagues get a placeholder: an empty off-season block
      // should stay hidden rather than push the rest of the page down.
      return leagueNews.isLoading && isFollowing
          ? _LeagueNewsSkeleton(label: leagueLabel)
          : const SizedBox.shrink();
    }

    final LeagueLook look = LeagueLook.forLabel(leagueLabel);

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[look.top, look.bottom],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: GestureDetector(
                    onTap: onLeagueTap,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: <Widget>[
                        Icon(look.icon, color: Colors.white, size: 28),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            leagueLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.typography.screenTitle.copyWith(
                              color: Colors.white,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                _FollowPill(
                  isFollowing: isFollowing,
                  onPressed: onToggleFollow,
                ),
              ],
            ),
          ),
          if (games.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (
                    int index = 0;
                    index < games.length;
                    index++
                  ) ...<Widget>[
                    SizedBox(
                      width: 250,
                      child: GestureDetector(
                        onTap: () => onGameTap(games[index]),
                        child: ScoreCard(game: games[index]),
                      ),
                    ),
                    if (index != games.length - 1)
                      const SizedBox(width: AppSpacing.md),
                  ],
                ],
              ),
            ),
          if (shownStories.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _HeroStory(article: shownStories.first, onTap: onArticleTap),
            for (final Article article in shownStories.skip(1))
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: ArticleTile(
                  article: article,
                  showSummary: false,
                  showThumbnail: true,
                  onTap: () => onArticleTap(article),
                  onLike: () {},
                  onMore: (ArticleAction action) =>
                      handleArticleAction(context, ref, article, action),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onMore,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        'More $leagueLabel stories',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.meta.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _FollowPill extends StatelessWidget {
  const _FollowPill({required this.isFollowing, required this.onPressed});

  final bool isFollowing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white70),
          color: isFollowing ? Colors.white24 : Colors.transparent,
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Full-bleed hero story: photo, publisher mark, headline and age overlay.
class _HeroStory extends StatelessWidget {
  const _HeroStory({required this.article, required this.onTap});

  final Article article;
  final ValueChanged<Article> onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(article),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                SlNetworkImage(
                  url: article.imageUrl,
                  fit: BoxFit.cover,
                  placeholderLabel: article.publisher.mark,
                  seed: article.id,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Colors.transparent, Color(0xB3000000)],
                      stops: <double>[0.35, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  top: 12,
                  child: PublisherMark(
                    publisher: article.publisher,
                    logoHeight: 16,
                    color: Colors.white,
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        article.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.sectionTitle.copyWith(
                          color: Colors.white,
                          fontSize: 22,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        article.relativeAge,
                        style: context.typography.meta.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder while a league's own feed loads, so the Sports feed keeps its
/// rhythm instead of sections appearing one by one.
class _LeagueNewsSkeleton extends StatelessWidget {
  const _LeagueNewsSkeleton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final LeagueLook look = LeagueLook.forLabel(label);
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xxl),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[look.top, look.bottom],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(look.icon, color: Colors.white, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.screenTitle.copyWith(
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const SkeletonBox(height: 150),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonBox(height: 64),
        ],
      ),
    );
  }
}
