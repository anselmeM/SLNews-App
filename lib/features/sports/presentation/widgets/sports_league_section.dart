import 'package:flutter/material.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/domain/models/sports_models.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/article_tile.dart';
import '../../../../core/widgets/publisher_mark.dart';
import '../../../../core/widgets/sl_network_image.dart';
import 'score_card.dart';

/// One Samsung-style league block in the Sports feed.
///
/// A coloured header with the league name and a Follow pill, the league's score
/// cards, a full-bleed hero story, compact stories and a "More … stories" link —
/// matching the reference Sports tab.
class SportsLeagueSection extends StatelessWidget {
  const SportsLeagueSection({
    super.key,
    required this.leagueLabel,
    required this.games,
    required this.articles,
    required this.isFollowing,
    required this.onToggleFollow,
    required this.onArticleTap,
    required this.onMore,
    required this.onGameTap,
    required this.onLeagueTap,
  });

  final String leagueLabel;
  final List<GameScore> games;
  final List<Article> articles;
  final bool isFollowing;
  final VoidCallback onToggleFollow;
  final ValueChanged<Article> onArticleTap;
  final VoidCallback onMore;
  final ValueChanged<GameScore> onGameTap;
  final VoidCallback onLeagueTap;

  @override
  Widget build(BuildContext context) {
    final _LeagueLook look = _LeagueLook.forLabel(leagueLabel);
    final List<Article> stories = articles.take(4).toList(growable: false);

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
            SizedBox(
              height: 156,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                itemCount: games.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (BuildContext context, int index) {
                  final GameScore game = games[index];
                  return SizedBox(
                    width: 250,
                    child: GestureDetector(
                      onTap: () => onGameTap(game),
                      child: ScoreCard(game: game),
                    ),
                  );
                },
              ),
            ),
          if (stories.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _HeroStory(article: stories.first, onTap: onArticleTap),
            for (final Article article in stories.skip(1))
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
                  onMore: (_) {},
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onMore,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'More $leagueLabel stories',
                      style: context.typography.meta.copyWith(
                        color: Colors.white,
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

class _LeagueLook {
  const _LeagueLook(this.icon, this.top, this.bottom);

  final IconData icon;
  final Color top;
  final Color bottom;

  static _LeagueLook forLabel(String label) {
    final String value = label.toUpperCase();
    if (value.contains('NBA')) {
      return const _LeagueLook(
        Icons.sports_basketball,
        Color(0xFF0B2E6B),
        Color(0xFF1558B0),
      );
    }
    if (value.contains('NFL')) {
      return const _LeagueLook(
        Icons.sports_football,
        Color(0xFF0A2A22),
        Color(0xFF146B4A),
      );
    }
    if (value.contains('MLB')) {
      return const _LeagueLook(
        Icons.sports_baseball,
        Color(0xFF1C2340),
        Color(0xFF31508E),
      );
    }
    if (value.contains('NHL')) {
      return const _LeagueLook(
        Icons.sports_hockey,
        Color(0xFF1A1A1E),
        Color(0xFF3A3A42),
      );
    }
    if (value.contains('PREMIER')) {
      return const _LeagueLook(
        Icons.sports_soccer,
        Color(0xFF2B0A45),
        Color(0xFF5B1E8A),
      );
    }
    return const _LeagueLook(
      Icons.sports_soccer,
      Color(0xFF062E1C),
      Color(0xFF0F5A37),
    );
  }
}
