import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/api_client.dart';
import 'package:slnews_mobile/core/data/sources/espn_source.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';

import '../../data/fakes.dart';

void main() {
  group('ESPN catalogue mapping', () {
    test('maps the Lakers catalogue id to ESPN NBA', () {
      expect(EspnSource.supportsTeamId('team:lal'), isTrue);
      expect(EspnSource.leagueIdForTeam('team:lal'), 'nba');
      expect(EspnSource.refForTeam('team:lal')!.teamId, '13');
      expect(EspnSource.supportsTeamId('team:leone-stars'), isFalse);
      // Standings emit the ESPN alias; it must resolve to the same catalogue team.
      expect(EspnSource.supportsTeamId('team:espn-13'), isTrue);
      expect(EspnSource.refForTeam('team:espn-13')!.teamId, '13');
      expect(EspnSource.leagueIdForTeam('team:espn-13'), 'nba');
    });

    test('maps followed leagues to ESPN standings paths', () {
      expect(EspnSource.supportsLeagueId('league:nba'), isTrue);
      expect(EspnSource.supportsLeagueId('league:epl'), isTrue);
      expect(EspnSource.supportsLeagueId('league:spl'), isFalse);
      expect(EspnSource.leagueLabel('nba'), 'NBA');
    });
  });

  test('team news maps, tags and limits articles', () async {
    final fake = dioWith(
      (RequestOptions options) async => jsonBody(
        jsonEncode(<String, dynamic>{
          'articles': <Object?>[
            <String, dynamic>{
              'id': 1,
              'headline': 'Lakers hold on in overtime',
              'description': 'A late run sealed it.',
              'published': '2026-11-20T10:00:00Z',
              'links': <String, dynamic>{
                'web': <String, dynamic>{'href': 'https://espn.com/nba/1'},
              },
              'categories': <Object?>[
                <String, dynamic>{'type': 'team', 'teamId': 13},
                <String, dynamic>{'type': 'league', 'leagueId': 'nba'},
              ],
            },
            <String, dynamic>{'id': 2, 'headline': 'Not selected'},
          ],
        }),
      ),
    );
    final EspnSource source = EspnSource(client: ApiClient(dio: fake.dio));

    final List<Article> articles = await source.teamNews('team:lal', limit: 1);

    expect(articles, hasLength(1));
    expect(articles.single.title, 'Lakers hold on in overtime');
    expect(
      articles.single.tags,
      containsAll(<String>['sports', 'team:lal', 'league:nba']),
    );
    expect(articles.single.previewOnly, isTrue);
    expect(articles.single.sourceUrl, 'https://espn.com/nba/1');
    expect(fake.adapter.requests.single.queryParameters['team'], '13');
    expect(fake.adapter.requests.single.queryParameters['limit'], 1);
  });

  test('team news is best-effort when the wire fails', () async {
    final fake = dioWith(
      (RequestOptions options) async => throw StateError('offline'),
    );
    final EspnSource source = EspnSource(client: ApiClient(dio: fake.dio));

    expect(await source.teamNews('team:lal'), isEmpty);
    expect(await source.teamNews('team:unknown'), isEmpty);
    expect(fake.adapter.requests, hasLength(1));
  });

  test('standings flatten, sort and cache entries', () async {
    final fake = dioWith(
      (RequestOptions options) async => jsonBody(
        jsonEncode(<String, dynamic>{
          'children': <Object?>[
            <String, dynamic>{
              'standings': <String, dynamic>{
                'entries': <Object?>[
                  <String, dynamic>{
                    'team': <String, dynamic>{
                      'id': '2',
                      'displayName': 'Boston Celtics',
                      'abbreviation': 'BOS',
                    },
                    'stats': <Object?>[
                      <String, dynamic>{'name': 'wins', 'value': 8},
                      <String, dynamic>{'name': 'losses', 'value': 7},
                    ],
                  },
                  <String, dynamic>{
                    'team': <String, dynamic>{
                      'id': '13',
                      'displayName': 'Los Angeles Lakers',
                      'abbreviation': 'LAL',
                    },
                    'stats': <Object?>[
                      <String, dynamic>{'name': 'wins', 'value': 10},
                      <String, dynamic>{'name': 'losses', 'value': 5},
                    ],
                  },
                  <String, dynamic>{
                    'team': <String, dynamic>{'id': 'empty'},
                  },
                ],
              },
            },
          ],
        }),
      ),
    );
    final EspnSource source = EspnSource(client: ApiClient(dio: fake.dio));

    final first = await source.standings('league:nba');
    final second = await source.standings('nba');
    final int requestsAfterFirst = fake.adapter.requests.length;

    expect(first, hasLength(2));
    expect(first.first.team.name, 'Los Angeles Lakers');
    expect(first.first.team.id, 'team:espn-13');
    expect(first.first.record, '10-5');
    expect(first.first.rank, 1);
    expect(first.last.team.name, 'Boston Celtics');
    expect(second, same(first));
    expect(fake.adapter.requests.length, requestsAfterFirst);
    expect(await source.standings('league:unknown'), isEmpty);
    expect(await source.standings('league:spl'), isEmpty);
  });

  test('standings are best-effort when the wire fails', () async {
    final fake = dioWith(
      (RequestOptions options) async => throw StateError('offline'),
    );
    final EspnSource source = EspnSource(client: ApiClient(dio: fake.dio));

    expect(await source.standings('league:epl'), isEmpty);
  });
}
