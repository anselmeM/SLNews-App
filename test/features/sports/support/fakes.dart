import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/publisher.dart';
import 'package:slnews_mobile/core/domain/models/sports_models.dart';

export '../../../support/fakes.dart';

/// An article with the minimum fields the tile needs.
Article buildArticle({
  required String id,
  required String title,
  String publisherName = 'Awoko Newspaper',
  DateTime? publishedAt,
}) {
  return Article(
    id: id,
    title: title,
    publisher: Publisher(id: 'awoko', name: publisherName, wordmark: 'AWOKO'),
    publishedAt: publishedAt ?? DateTime(2026, 10, 15, 18),
    categoryId: 'sports',
    summary: 'Match report and reaction.',
  );
}

/// A scoreboard fixture.
GameScore buildGame({
  required String id,
  String leagueLabel = 'NBA',
  Team? home,
  Team? away,
  GameStatus status = GameStatus.scheduled,
  int? homeScore,
  int? awayScore,
  DateTime? startsAt,
  String? periodLabel,
}) {
  return GameScore(
    id: id,
    leagueLabel: leagueLabel,
    home:
        home ??
        const Team(id: 'team:lal', name: 'Los Angeles Lakers', code: 'LAL'),
    away:
        away ?? const Team(id: 'team:bos', name: 'Boston Celtics', code: 'BOS'),
    status: status,
    homeScore: homeScore,
    awayScore: awayScore,
    startsAt: startsAt,
    periodLabel: periodLabel,
  );
}
