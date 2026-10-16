import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sync/remote_sync_source.dart';
import 'package:slnews_mobile/core/data/sync/sync_api_config.dart';
import 'package:slnews_mobile/core/data/sources/api_client.dart';
import 'package:slnews_mobile/core/domain/sync/sync_repository.dart';

import 'support/fakes.dart';

void main() {
  group('SyncApiConfig', () {
    test('endpoint is the PWA origin plus the frozen mobile path', () {
      const SyncApiConfig config = SyncApiConfig(baseUrl: 'https://slnews.sl');

      expect(config.endpoint, 'https://slnews.sl/api/mobile/v1/sync');
      expect(config.host, 'slnews.sl');
      expect(config.isConfigured, isTrue);
      expect(config.limit, SyncApiConfig.defaultLimit);
    });

    test('a trailing slash never doubles up in the path', () {
      const SyncApiConfig config = SyncApiConfig(
        baseUrl: 'https://slnews.sl///',
      );

      expect(config.endpoint, 'https://slnews.sl/api/mobile/v1/sync');
    });

    test('accepts a Vercel preview origin', () {
      const SyncApiConfig config = SyncApiConfig(
        baseUrl: 'https://slnews-git-sync-team.vercel.app',
      );

      expect(config.endpoint, endsWith('/api/mobile/v1/sync'));
      expect(config.host, 'slnews-git-sync-team.vercel.app');
    });

    test('an empty origin disables sync', () {
      expect(unconfiguredSyncConfig.isConfigured, isFalse);
      expect(unconfiguredSyncConfig.host, isEmpty);
      expect(const SyncApiConfig(baseUrl: '   ').isConfigured, isFalse);
    });

    test('fromEnvironment defaults to the PWA origin with no dart-define', () {
      final SyncApiConfig config = SyncApiConfig.fromEnvironment();

      // No --dart-define is present when this suite runs.
      expect(config.baseUrl, SyncApiConfig.defaultBaseUrl);
      expect(config.baseUrl, 'https://sl-news.vercel.app');
      expect(config.isConfigured, isTrue);
      expect(config.limit, SyncApiConfig.defaultLimit);
    });

    test('clamps the limit into the range the API accepts', () {
      const SyncApiConfig base = SyncApiConfig(baseUrl: testSyncOrigin);

      expect(base.copyWith(limit: 0).limit, 1);
      expect(base.copyWith(limit: 10000).limit, 500);
      expect(base.copyWith(limit: 250).limit, 250);
      expect(base.copyWith(baseUrl: '').isConfigured, isFalse);
    });

    test('toString never exposes anything but the host', () {
      expect(
        testSyncConfig.toString(),
        'SyncApiConfig(sync.test, limit: 500, enabled)',
      );
      expect(unconfiguredSyncConfig.toString(), contains('disabled'));
    });
  });

  group('RemoteSyncSource.pull — request shape', () {
    test('GETs the sync endpoint with the configured limit', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.json(pullEnvelope()),
      );

      await harness.source.pull();

      expect(harness.request.method, 'GET');
      expect(harness.request.uri.path, '/api/mobile/v1/sync');
      expect(harness.request.uri.host, 'sync.test');
      expect(harness.query, <String, dynamic>{'limit': 500});
    });

    test('sends since as an ISO-8601 UTC instant with milliseconds', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.json(pullEnvelope()),
      );

      await harness.source.pull(
        since: DateTime.utc(2026, 10, 16, 4, 51, 2, 114),
      );

      expect(harness.query['since'], '2026-10-16T04:51:02.114Z');
    });

    test('omits since entirely for a full-state pull', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.json(pullEnvelope()),
      );

      await harness.source.pull();

      expect(harness.query.containsKey('since'), isFalse);
    });

    test('attaches the session token to an allow-listed host only', () async {
      final SyncHarness allowed = SyncHarness(
        (RequestOptions options) async => SyncHarness.json(pullEnvelope()),
        authTokenProvider: () async => 'clerk-jwt',
        authTokenHosts: const <String>{'sync.test'},
      );
      final SyncHarness denied = SyncHarness(
        (RequestOptions options) async => SyncHarness.json(pullEnvelope()),
        authTokenProvider: () async => 'clerk-jwt',
        authTokenHosts: const <String>{'slnews.sl'},
      );

      await allowed.source.pull();
      await denied.source.pull();

      expect(allowed.request.headers['authorization'], 'Bearer clerk-jwt');
      expect(denied.request.headers.containsKey('authorization'), isFalse);
    });
  });

  group('RemoteSyncSource.pull — parsing', () {
    test('parses a full response, including tombstones', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.json(
          pullEnvelope(
            bookmarks: <Map<String, dynamic>>[
              bookmarkRow(
                'slnews-api:4821',
                updatedAt: '2026-10-16T04:51:02.114Z',
              ),
              bookmarkRow(
                'rss:9f2c4a1b77e0d135',
                updatedAt: '2026-10-16T04:52:00.000Z',
                deleted: true,
                title: '',
              ),
            ],
            reactions: <Map<String, dynamic>>[
              reactionRow(
                'slnews-api:4821',
                updatedAt: '2026-10-16T04:51:02.114Z',
              ),
            ],
            follows: <Map<String, dynamic>>[
              followRow(
                'team:lal',
                updatedAt: '2026-10-16T04:53:00.000Z',
                kind: 'team',
                label: 'Los Angeles Lakers',
              ),
            ],
          ),
        ),
      );

      final SyncState state = await harness.source.pull();

      expect(state.bookmarks, hasLength(2));
      final SyncBookmark saved = state.bookmarks.first;
      expect(saved.itemId, 'slnews-api:4821');
      expect(saved.title, 'Leone Stars level with Guinea');
      expect(saved.sourceUrl, 'https://example.test/slnews-api:4821');
      expect(saved.imageUrl, isNull);
      expect(saved.publisher, 'The Sierra Leone Telegraph');
      expect(saved.publishedAt, DateTime.utc(2026, 10, 15, 20, 12));
      expect(saved.savedAt, DateTime.utc(2026, 10, 16, 4, 51, 2, 114));
      expect(saved.updatedAt, DateTime.utc(2026, 10, 16, 4, 51, 2, 114));
      expect(saved.deleted, isFalse);

      final SyncBookmark tombstone = state.bookmarks.last;
      expect(tombstone.itemId, 'rss:9f2c4a1b77e0d135');
      expect(tombstone.deleted, isTrue);

      expect(state.reactions.single.kind, 'like');
      expect(state.activeReactions, hasLength(1));
      expect(state.follows.single.targetId, 'team:lal');
      expect(state.follows.single.label, 'Los Angeles Lakers');
      expect(state.serverTime, DateTime.utc(2026, 10, 16, 5));
      expect(state.hasMore, isFalse);
      expect(state.activeBookmarks, hasLength(1));
    });

    test('an absent collection is empty, not an error', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.json(<String, dynamic>{
          'serverTime': '2026-10-16T05:00:00.000Z',
        }),
      );

      final SyncState state = await harness.source.pull();

      expect(state.isEmpty, isTrue);
      expect(state.serverTime, DateTime.utc(2026, 10, 16, 5));
    });

    test('hasMore is carried through for the follow-up pull', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.json(
          pullEnvelope(
            bookmarks: <Map<String, dynamic>>[
              bookmarkRow('a', updatedAt: '2026-10-16T04:00:00.000Z'),
            ],
            hasMore: true,
          ),
        ),
      );

      final SyncState state = await harness.source.pull();

      expect(state.hasMore, isTrue);
      // The truncation cursor the caller re-issues with.
      expect(state.latestUpdatedAt, DateTime.utc(2026, 10, 16, 4));
    });

    test('a missing serverTime falls back to the newest row', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.json(
          pullEnvelope(
            includeServerTime: false,
            bookmarks: <Map<String, dynamic>>[
              bookmarkRow('a', updatedAt: '2026-10-16T03:00:00.000Z'),
              bookmarkRow('b', updatedAt: '2026-10-16T07:30:00.000Z'),
            ],
          ),
        ),
      );

      final SyncState state = await harness.source.pull();

      expect(state.serverTime, DateTime.utc(2026, 10, 16, 7, 30));
    });

    test('a missing serverTime on an empty response is not null', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async =>
            SyncHarness.json(pullEnvelope(includeServerTime: false)),
      );

      final SyncState state = await harness.source.pull();

      expect(state.serverTime, isNotNull);
      expect(state.isEmpty, isTrue);
    });

    test('tolerates epoch timestamps and missing optional fields', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.json(
          pullEnvelope(
            bookmarks: <Map<String, dynamic>>[
              <String, dynamic>{
                'itemId': 'slnews-api:1',
                'title': 'Epoch row',
                'updatedAt': 1791537600,
              },
            ],
          ),
        ),
      );

      final SyncState state = await harness.source.pull();

      expect(
        state.bookmarks.single.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(1791537600000, isUtc: true),
      );
      expect(state.bookmarks.single.sourceUrl, isNull);
      // savedAt defaults to updatedAt when the server omits it.
      expect(state.bookmarks.single.savedAt, state.bookmarks.single.updatedAt);
    });

    test(
      'skips a row with no identity key instead of failing the response',
      () async {
        final SyncHarness harness = SyncHarness(
          (RequestOptions options) async => SyncHarness.json(
            pullEnvelope(
              bookmarks: <Map<String, dynamic>>[
                <String, dynamic>{
                  'title': 'No id',
                  'updatedAt': '2026-10-16T04:00:00.000Z',
                },
                bookmarkRow(
                  'slnews-api:2',
                  updatedAt: '2026-10-16T04:00:00.000Z',
                ),
              ],
              reactions: const <Map<String, dynamic>>[
                <String, dynamic>{'kind': 'like'},
              ],
            ),
          ),
        );

        final SyncState state = await harness.source.pull();

        expect(state.bookmarks.single.itemId, 'slnews-api:2');
        expect(state.reactions, isEmpty);
      },
    );

    test('ignores a collection that is not a list', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.json(<String, dynamic>{
          'serverTime': '2026-10-16T05:00:00.000Z',
          'bookmarks': <String>['not-a-row'],
          'reactions': null,
          'follows': 42,
        }),
      );

      final SyncState state = await harness.source.pull();

      expect(state.isEmpty, isTrue);
    });
  });

  group('RemoteSyncSource.pull — degraded paths', () {
    test('401 maps to SyncUnauthorized and yields an empty state', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.error(401),
      );

      final SyncState state = await harness.source.pull();

      expect(state.isEmpty, isTrue);
      expect(harness.source.lastFailure, isA<SyncUnauthorized>());
    });

    test('429 maps to SyncRateLimited', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.error(
          429,
          headers: <String, String>{'Retry-After': '900'},
        ),
      );

      final SyncState state = await harness.source.pull();

      expect(state.isEmpty, isTrue);
      expect(harness.source.lastFailure, isA<SyncRateLimited>());
    });

    test('400 and 413 map to SyncRejected (the payload is at fault)', () async {
      final SyncHarness bad = SyncHarness(
        (RequestOptions options) async => SyncHarness.error(400),
      );
      final SyncHarness big = SyncHarness(
        (RequestOptions options) async => SyncHarness.error(413),
      );

      await bad.source.pull();
      await big.source.pull();

      expect(bad.source.lastFailure, isA<SyncRejected>());
      expect(big.source.lastFailure, isA<SyncRejected>());
      expect((big.source.lastFailure! as SyncRejected).statusCode, 413);
    });

    test('a timeout maps to SyncUnavailable', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => throw SyncHarness.timeout(options),
      );

      final SyncState state = await harness.source.pull();

      expect(state.isEmpty, isTrue);
      expect(harness.source.lastFailure, isA<SyncUnavailable>());
      expect(
        (harness.source.lastFailure! as SyncUnavailable).statusCode,
        isNull,
      );
    });

    test('a 500 maps to SyncUnavailable and does not throw', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.error(500),
      );

      final SyncState state = await harness.source.pull();

      expect(state.isEmpty, isTrue);
      expect(harness.source.lastFailure, isA<SyncUnavailable>());
      expect((harness.source.lastFailure! as SyncUnavailable).statusCode, 500);
    });

    test('malformed JSON yields an empty state', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.malformed(),
      );

      final SyncState state = await harness.source.pull();

      expect(state.isEmpty, isTrue);
      expect(state.hasMore, isFalse);
      expect(harness.source.isConfigured, isTrue);
    });

    test('a non-object payload yields an empty state', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.json('just a string'),
      );

      expect((await harness.source.pull()).isEmpty, isTrue);
    });

    test('an unconfigured source issues no request at all', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async =>
            fail('a disabled source must not issue a request'),
        config: unconfiguredSyncConfig,
      );

      expect(harness.source.isConfigured, isFalse);
      expect((await harness.source.pull()).isEmpty, isTrue);
      expect((await harness.source.push(const SyncState.empty())).ok, isFalse);
      expect(harness.adapter.requests, isEmpty);
    });

    test('a success clears lastFailure', () async {
      int calls = 0;
      final SyncHarness harness = SyncHarness((RequestOptions options) async {
        calls += 1;
        return calls == 1
            ? SyncHarness.error(500)
            : SyncHarness.json(pullEnvelope());
      });

      await harness.source.pull();
      expect(harness.source.lastFailure, isNotNull);
      await harness.source.pull();
      expect(harness.source.lastFailure, isNull);
    });
  });

  group('RemoteSyncSource.push — request shape', () {
    test('POSTs every collection, tombstones included', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.json(pushEnvelope()),
      );
      final SyncState local = SyncState(
        bookmarks: <SyncBookmark>[
          bookmark(
            'slnews-api:4821',
            updatedAt: DateTime.utc(2026, 10, 16, 4, 51, 2, 114),
          ),
          deletedBookmark(
            'rss:aa',
            updatedAt: DateTime.utc(2026, 10, 16, 4, 52),
          ),
        ],
        reactions: <SyncReaction>[
          reaction(
            'slnews-api:4821',
            updatedAt: DateTime.utc(2026, 10, 16, 4, 51, 2, 114),
          ),
        ],
        follows: <SyncFollow>[
          follow(
            'team:lal',
            updatedAt: DateTime.utc(2026, 10, 16, 4, 53),
            kind: 'team',
            label: 'Los Angeles Lakers',
          ),
        ],
      );

      await harness.source.push(local);

      expect(harness.request.method, 'POST');
      expect(harness.request.uri.path, '/api/mobile/v1/sync');
      expect(harness.request.contentType, contains('application/json'));

      final List<dynamic> bookmarks =
          harness.body['bookmarks'] as List<dynamic>;
      expect(bookmarks, hasLength(2));
      final Map<String, dynamic> first = Map<String, dynamic>.from(
        bookmarks.first as Map<dynamic, dynamic>,
      );
      expect(first['itemId'], 'slnews-api:4821');
      expect(first['updatedAt'], '2026-10-16T04:51:02.114Z');
      expect(first['savedAt'], '2026-10-16T04:51:02.114Z');
      expect(first['publishedAt'], '2026-10-16T02:51:02.114Z');
      expect(first['deleted'], isFalse);

      final Map<String, dynamic> tombstone = Map<String, dynamic>.from(
        bookmarks.last as Map<dynamic, dynamic>,
      );
      expect(tombstone['itemId'], 'rss:aa');
      expect(tombstone['deleted'], isTrue);

      final Map<String, dynamic> followRow = Map<String, dynamic>.from(
        (harness.body['follows'] as List<dynamic>).single
            as Map<dynamic, dynamic>,
      );
      expect(followRow['targetId'], 'team:lal');
      expect(followRow['kind'], 'team');
      expect(followRow['label'], 'Los Angeles Lakers');
      expect(followRow['updatedAt'], '2026-10-16T04:53:00.000Z');

      final Map<String, dynamic> reactionRow = Map<String, dynamic>.from(
        (harness.body['reactions'] as List<dynamic>).single
            as Map<dynamic, dynamic>,
      );
      expect(reactionRow['itemId'], 'slnews-api:4821');
      expect(reactionRow['kind'], 'like');
      expect(reactionRow['deleted'], isFalse);
    });

    test('sends all three arrays even when the state is empty', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.json(pushEnvelope()),
      );

      await harness.source.push(const SyncState.empty());

      expect(
        harness.body.keys,
        containsAll(<String>['bookmarks', 'reactions', 'follows']),
      );
      expect(harness.body['bookmarks'], isEmpty);
      expect(harness.body['reactions'], isEmpty);
      expect(harness.body['follows'], isEmpty);
    });

    test('a local timestamp is always serialised as UTC', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.json(pushEnvelope()),
      );
      final DateTime local = DateTime(2026, 10, 16, 4, 51, 2, 114);

      await harness.source.push(
        SyncState(
          bookmarks: <SyncBookmark>[
            SyncBookmark(
              itemId: 'a',
              title: 'Local time',
              updatedAt: local,
              savedAt: local,
            ),
          ],
        ),
      );

      final Map<String, dynamic> row = Map<String, dynamic>.from(
        (harness.body['bookmarks'] as List<dynamic>).single
            as Map<dynamic, dynamic>,
      );
      // `toUtc()` shifts the wall clock but keeps the instant.
      expect(row['updatedAt'], local.toUtc().toIso8601String());
      expect(row['updatedAt'], endsWith('Z'));
    });
  });

  group('RemoteSyncSource.push — parsing', () {
    test('reports applied counts, rejections and the returned state', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.json(
          pushEnvelope(
            applied: <String, dynamic>{
              'bookmarks': 3,
              'reactions': 1,
              'follows': 0,
            },
            rejected: <Map<String, dynamic>>[
              <String, dynamic>{
                'collection': 'bookmarks',
                'itemId': 'slnews-api:4821',
                'reason': 'stale',
              },
            ],
            state: <String, dynamic>{
              'bookmarks': <Map<String, dynamic>>[
                bookmarkRow(
                  'slnews-api:4821',
                  updatedAt: '2026-10-16T06:00:00.000Z',
                ),
              ],
            },
          ),
        ),
      );

      final SyncResult result = await harness.source.push(
        SyncState(
          bookmarks: <SyncBookmark>[
            bookmark(
              'slnews-api:4821',
              updatedAt: DateTime.utc(2026, 10, 16, 4),
            ),
          ],
        ),
      );

      expect(result.ok, isTrue);
      expect(result.failure, isNull);
      expect(result.applied.bookmarks, 3);
      expect(result.applied.reactions, 1);
      expect(result.applied.total, 4);
      expect(result.applied.forCollection('follows'), 0);
      // A rejection is reported per row and is not a failure.
      expect(result.rejected, hasLength(1));
      expect(result.rejected.single.collection, 'bookmarks');
      expect(result.rejected.single.id, 'slnews-api:4821');
      expect(result.rejected.single.reason, 'stale');
      // The server's own row is the converged value.
      expect(
        result.state.bookmarks.single.updatedAt,
        DateTime.utc(2026, 10, 16, 6),
      );
    });

    test('accepts targetId and a bare id in a rejection', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.json(
          pushEnvelope(
            rejected: <Map<String, dynamic>>[
              <String, dynamic>{
                'collection': 'follows',
                'targetId': 'team:lal',
                'reason': 'stale',
              },
              <String, dynamic>{
                'collection': 'reactions',
                'id': 'slnews-api:9',
                'reason': 'invalid',
              },
            ],
          ),
        ),
      );

      final SyncResult result = await harness.source.push(
        const SyncState.empty(),
      );

      expect(result.rejected.map((SyncRejection r) => r.id), <String>[
        'team:lal',
        'slnews-api:9',
      ]);
      expect(result.rejected.last.reason, 'invalid');
    });

    test('a server response without state falls back to the sent rows', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.json(
          pushEnvelope(
            applied: <String, dynamic>{
              'bookmarks': 1,
              'reactions': 0,
              'follows': 1,
            },
            rejected: <Map<String, dynamic>>[
              <String, dynamic>{
                'collection': 'bookmarks',
                'itemId': 'stale',
                'reason': 'stale',
              },
            ],
          ),
        ),
      );
      final SyncState sent = SyncState(
        bookmarks: <SyncBookmark>[
          bookmark('stale', updatedAt: DateTime.utc(2026, 10, 16, 4)),
          bookmark('fresh', updatedAt: DateTime.utc(2026, 10, 16, 5)),
        ],
        follows: <SyncFollow>[
          follow('team:lal', updatedAt: DateTime.utc(2026, 10, 16, 5)),
        ],
      );

      final SyncResult result = await harness.source.push(sent);

      expect(result.ok, isTrue);
      // The rejected row is dropped; everything else is reported as converged.
      expect(result.state.bookmarks.map((SyncBookmark r) => r.itemId), <String>[
        'fresh',
      ]);
      expect(result.state.follows, hasLength(1));
      // The cursor does not move backwards: the push's own serverTime is used.
      expect(result.state.serverTime, DateTime.utc(2026, 10, 16, 5));
    });

    test(
      'an empty rejected array and missing applied object are tolerated',
      () async {
        final SyncHarness harness = SyncHarness(
          (RequestOptions options) async => SyncHarness.json(<String, dynamic>{
            'serverTime': '2026-10-16T05:00:00.000Z',
            'state': pullEnvelope(),
          }),
        );

        final SyncResult result = await harness.source.push(
          const SyncState.empty(),
        );

        expect(result.ok, isTrue);
        expect(result.rejected, isEmpty);
        expect(result.applied, SyncApplied.none);
      },
    );

    test('a malformed push body does not throw', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.malformed(),
      );

      final SyncResult result = await harness.source.push(
        SyncState(
          bookmarks: <SyncBookmark>[
            bookmark('a', updatedAt: DateTime.utc(2026, 10, 16, 4)),
          ],
        ),
      );

      expect(result.ok, isFalse);
      expect(result.failure, isA<SyncUnavailable>());
      // The caller still gets its rows back, minus nothing.
      expect(result.state.bookmarks, hasLength(1));
    });

    test('401 and 429 on a push produce typed failures', () async {
      final SyncHarness unauthorized = SyncHarness(
        (RequestOptions options) async => SyncHarness.error(401),
      );
      final SyncHarness limited = SyncHarness(
        (RequestOptions options) async => SyncHarness.error(429),
      );

      final SyncResult first = await unauthorized.source.push(
        const SyncState.empty(),
      );
      final SyncResult second = await limited.source.push(
        const SyncState.empty(),
      );

      expect(first.ok, isFalse);
      expect(first.failure, isA<SyncUnauthorized>());
      expect(second.failure, isA<SyncRateLimited>());
      expect(unauthorized.source.lastFailure, isA<SyncUnauthorized>());
      expect(limited.source.lastFailure, isA<SyncRateLimited>());
    });

    test('413 on a push produces SyncRejected', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => SyncHarness.error(413),
      );

      final SyncResult result = await harness.source.push(
        const SyncState.empty(),
      );

      expect(result.failure, isA<SyncRejected>());
      expect((result.failure! as SyncRejected).statusCode, 413);
    });

    test('a timeout on a push produces SyncUnavailable', () async {
      final SyncHarness harness = SyncHarness(
        (RequestOptions options) async => throw SyncHarness.timeout(options),
      );

      final SyncResult result = await harness.source.push(
        const SyncState.empty(),
      );

      expect(result.failure, isA<SyncUnavailable>());
    });
  });

  group('failure mapping helpers', () {
    test('failureFor maps each contract status code', () {
      expect(
        RemoteSyncSource.failureFor(ApiException('nope', statusCode: 401)),
        isA<SyncUnauthorized>(),
      );
      expect(
        RemoteSyncSource.failureFor(ApiException('nope', statusCode: 429)),
        isA<SyncRateLimited>(),
      );
      expect(
        RemoteSyncSource.failureFor(ApiException('nope', statusCode: 400)),
        isA<SyncRejected>(),
      );
      expect(
        RemoteSyncSource.failureFor(ApiException('nope', statusCode: 413)),
        isA<SyncRejected>(),
      );
      expect(
        RemoteSyncSource.failureFor(ApiException('nope', statusCode: 500)),
        isA<SyncUnavailable>(),
      );
      // A transport fault has no status at all.
      expect(
        RemoteSyncSource.failureFor(ApiException('timed out')),
        isA<SyncUnavailable>(),
      );
      // A typed failure passes straight through.
      final SyncFailure typed = SyncFailure.unauthorized('already typed');
      expect(RemoteSyncSource.failureFor(typed), same(typed));
    });

    test('a thrown 429 still yields the Retry-After back-off', () {
      // `ApiException` carries the response headers, so the thrown path has the
      // same information as the non-throwing one; before that, a live 429 gave
      // `SyncRateLimited(retryAfter: null)`.
      final SyncFailure failure = RemoteSyncSource.failureFor(
        ApiException(
          'HTTP 429',
          statusCode: 429,
          responseHeaders: const <String, String>{'retry-after': '540'},
        ),
      );

      expect(failure, isA<SyncRateLimited>());
      expect(
        (failure as SyncRateLimited).retryAfter,
        const Duration(seconds: 540),
      );
    });

    test('an explicit retryAfter argument wins over the exception header', () {
      final SyncFailure failure = RemoteSyncSource.failureFor(
        ApiException(
          'HTTP 429',
          statusCode: 429,
          responseHeaders: const <String, String>{'retry-after': '540'},
        ),
        retryAfter: '30',
      );

      expect(
        (failure as SyncRateLimited).retryAfter,
        const Duration(seconds: 30),
      );
    });

    test('failureForResponse keeps the Retry-After hint', () {
      final SyncFailure limited = RemoteSyncSource.failureForResponse(
        const ApiResponse(
          data: null,
          statusCode: 429,
          headers: <String, String>{'retry-after': '540'},
        ),
      );

      expect(limited, isA<SyncRateLimited>());
      expect(
        (limited as SyncRateLimited).retryAfter,
        const Duration(seconds: 540),
      );
    });

    test('failureForResponse maps the rest of the contract', () {
      expect(
        RemoteSyncSource.failureForResponse(
          const ApiResponse(data: null, statusCode: 401),
        ),
        isA<SyncUnauthorized>(),
      );
      expect(
        RemoteSyncSource.failureForResponse(
          const ApiResponse(data: null, statusCode: 400),
        ),
        isA<SyncRejected>(),
      );
      expect(
        RemoteSyncSource.failureForResponse(
          const ApiResponse(data: null, statusCode: 503),
        ),
        isA<SyncUnavailable>(),
      );
      expect(
        RemoteSyncSource.failureForResponse(
          const ApiResponse(data: null, statusCode: null),
        ),
        isA<SyncUnavailable>(),
      );
    });

    test('parseRetryAfter accepts seconds, an HTTP-date and rubbish', () {
      expect(
        RemoteSyncSource.parseRetryAfter('900'),
        const Duration(seconds: 900),
      );
      expect(RemoteSyncSource.parseRetryAfter('-5'), Duration.zero);
      expect(RemoteSyncSource.parseRetryAfter(''), isNull);
      expect(RemoteSyncSource.parseRetryAfter('soon'), isNull);
      expect(RemoteSyncSource.parseRetryAfter(null), isNull);

      final String inAnHour = DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .toUtc()
          .toIso8601String();
      final Duration? parsed = RemoteSyncSource.parseRetryAfter(inAnHour);
      expect(parsed, isNotNull);
      expect(parsed!.inMinutes, inInclusiveRange(58, 60));

      // A date in the past means "retry now", never a negative wait.
      final String past = DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 1))
          .toIso8601String();
      expect(RemoteSyncSource.parseRetryAfter(past), Duration.zero);
    });

    test('failure kinds are the documented vocabulary', () {
      expect(SyncFailure.unauthorized('a').kind, 'unauthorized');
      expect(SyncFailure.rateLimited().kind, 'rateLimited');
      expect(SyncFailure.rejected().kind, 'rejected');
      expect(SyncFailure.unavailable('a').kind, 'unavailable');
      expect(
        const SyncRateLimited(retryAfter: Duration(seconds: 30)).toString(),
        contains('30s'),
      );
    });
  });
}
