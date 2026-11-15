import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/domain/models/sports_models.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/widgets/article_tile.dart';
import '../../../../core/widgets/publisher_mark.dart';
import '../../../../core/widgets/sl_network_image.dart';
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
    required this.articles,
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

  /// Strictly filtered local fallback while the league feed loads.
  final List<Article> articles;

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
    final List<Article> feed =
        ref.watch(leagueNewsProvider('league:$leagueId')).asData?.value ??
        const <Article>[];
    final List<Article> stories = preferredArticles.isNotEmpty
        ? preferredArticles
        : (feed.isNotEmpty ? feed : articles);
    final List<Article> shownStories = stories.take(4).toList(growable: false);

    // A section with neither a fixture nor a story is noise: the catalogue
    // includes off-season leagues, and their feeds may legitimately be empty.
    if (games.isEmpty && shownStories.isEmpty) return const SizedBox.shrink();

    final _LeagueLook look = _LeagueLook.forLabel(leagueLabel);

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
    if (value.contains('SIERRA LEONE PREMIER')) {
      return const _LeagueLook(
        Icons.sports_soccer,
        Color(0xFF062E1C),
        Color(0xFF0F7A43),
      );
    }
    if (value.contains('EUROPEAN')) {
      return const _LeagueLook(
        Icons.sports_soccer,
        Color(0xFF15102E),
        Color(0xFF3B2A7A),
      );
    }
    if (value.contains('CHAMPIONS LEAGUE')) {
      return const _LeagueLook(
        Icons.sports_soccer,
        Color(0xFF081A4B),
        Color(0xFF1746A2),
      );
    }
    if (value.contains('LA LIGA')) {
      return const _LeagueLook(
        Icons.sports_soccer,
        Color(0xFF4A1010),
        Color(0xFFB52A2A),
      );
    }
    if (value.contains('SERIE A')) {
      return const _LeagueLook(
        Icons.sports_soccer,
        Color(0xFF102A5E),
        Color(0xFF1D5AA6),
      );
    }
    if (value.contains('BUNDESLIGA')) {
      return const _LeagueLook(
        Icons.sports_soccer,
        Color(0xFF4A0A0A),
        Color(0xFFC21B1B),
      );
    }
    if (value.contains('LIGUE 1')) {
      return const _LeagueLook(
        Icons.sports_soccer,
        Color(0xFF0A2A4A),
        Color(0xFF1266A8),
      );
    }
    if (value.contains('AFCON')) {
      return const _LeagueLook(
        Icons.sports_soccer,
        Color(0xFF4A3200),
        Color(0xFFB3801A),
      );
    }
    if (value.contains('FORMULA')) {
      return const _LeagueLook(
        Icons.sports_motorsports,
        Color(0xFF3A0A0A),
        Color(0xFFB01818),
      );
    }
    if (value.contains('TENNIS')) {
      return const _LeagueLook(
        Icons.sports_tennis,
        Color(0xFF2A3A0A),
        Color(0xFF6B8A1A),
      );
    }
    if (value.contains('CRICKET')) {
      return const _LeagueLook(
        Icons.sports_cricket,
        Color(0xFF0A3A2A),
        Color(0xFF117A5A),
      );
    }
    if (value.contains('GOLF')) {
      return const _LeagueLook(
        Icons.golf_course,
        Color(0xFF0A3A0A),
        Color(0xFF1F7A1F),
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
