import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/publisher.dart';
import 'package:slnews_mobile/core/domain/sports_ranking.dart';

Article story({
  required String id,
  required String publisherId,
  required DateTime publishedAt,
}) {
  return Article(
    id: id,
    title: id,
    summary: '',
    bodyHtml: '',
    publisher: Publisher(id: publisherId, name: publisherId),
    publishedAt: publishedAt,
    categoryId: 'sports',
  );
}

void main() {
  test('local Sierra Leone sport leads, each group newest-first', () {
    final DateTime now = DateTime.utc(2026, 10, 22, 12);
    final List<Article> ranked = rankSportsStories(<Article>[
      story(id: 'bbc-new', publisherId: 'bbcsport', publishedAt: now),
      story(
        id: 'local-old',
        publisherId: 'footballsierraleone',
        publishedAt: now.subtract(const Duration(days: 2)),
      ),
      story(
        id: 'espn-new',
        publisherId: 'espn-nba',
        publishedAt: now.subtract(const Duration(minutes: 5)),
      ),
      story(
        id: 'local-new',
        publisherId: 'sierraloaded',
        publishedAt: now.subtract(const Duration(hours: 1)),
      ),
    ]);

    expect(ranked.map((Article a) => a.id).toList(), <String>[
      'local-new',
      'local-old',
      'bbc-new',
      'espn-new',
    ]);
  });

  test('does not mutate the input list', () {
    final DateTime now = DateTime.utc(2026, 10, 22, 12);
    final List<Article> input = <Article>[
      story(id: 'a', publisherId: 'bbcsport', publishedAt: now),
      story(id: 'b', publisherId: 'sltelegraph', publishedAt: now),
    ];
    rankSportsStories(input);
    expect(input.first.id, 'a');
  });
}
