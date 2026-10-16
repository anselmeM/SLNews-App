import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:slnews_mobile/core/data/seed/seed_data.dart';
import 'package:slnews_mobile/core/data/sources/feed_source.dart';
import 'package:slnews_mobile/core/domain/models/ad_unit.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/domain/models/notification_item.dart';
import 'package:slnews_mobile/core/domain/models/publisher.dart';
import 'package:slnews_mobile/core/domain/models/sports_models.dart';
import 'package:slnews_mobile/core/domain/models/weather_snapshot.dart';

/// Publisher attached to hand-built fixture articles.
const Publisher testPublisher = Publisher(
  id: 'awoko',
  name: 'Awoko Newspaper',
  wordmark: 'AWOKO',
);

/// Builds a feed configuration for [id], pointing at an unroutable test host.
FeedSourceConfig config(
  String id, {
  String categoryId = 'top',
  FeedSourceKind kind = FeedSourceKind.rss,
  String? url,
}) => FeedSourceConfig(
  id: id,
  outlet: 'Outlet $id',
  publisherId: id,
  wordmark: id.toUpperCase(),
  url: url ?? 'https://$id.test/feed/',
  kind: kind,
  categoryId: categoryId,
  websiteUrl: 'https://$id.test',
);

/// Builds one fixture article with sensible defaults.
Article article(
  String id, {
  String? title,
  String categoryId = 'top',
  DateTime? publishedAt,
  bool isBreaking = false,
  bool isLive = false,
  List<String> tags = const <String>[],
  Publisher publisher = testPublisher,
  String summary = 'Summary text',
  String bodyHtml = '<p>Body copy</p>',
}) => Article(
  id: id,
  title: title ?? 'Headline $id',
  summary: summary,
  bodyHtml: bodyHtml,
  publisher: publisher,
  publishedAt: publishedAt ?? DateTime.utc(2026, 10, 1, 12),
  categoryId: categoryId,
  tags: tags,
  isBreaking: isBreaking,
  isLive: isLive,
);

/// Builds a follow target for [id] with the kind implied by its prefix.
FollowTarget target(String id, {bool isPopular = false, String? label}) {
  final String prefix = id.split(':').first;
  return FollowTarget(
    id: id,
    // Location ids are prefixed `city:` while the wire value is `location`.
    kind: FollowKind.fromWire(prefix == 'city' ? 'location' : prefix),
    label: label ?? id.split(':').last,
    isPopular: isPopular,
  );
}

/// Builds a seed bundle for tests that must not touch assets.
SeedData seedData({
  List<Article> articles = const <Article>[],
  List<FollowTarget> followables = const <FollowTarget>[],
  List<NotificationItem> notifications = const <NotificationItem>[],
  List<AdUnit> ads = const <AdUnit>[],
  Map<String, WeatherSnapshot> weather = const <String, WeatherSnapshot>{},
  List<TeamStanding> standings = const <TeamStanding>[],
  List<GameScore> games = const <GameScore>[],
}) => SeedData(
  articles: articles,
  scoreboard: ScoreboardSnapshot(
    games: games,
    providerLabel: 'test/sports',
    updatedAt: DateTime.utc(2026, 10, 15, 12),
  ),
  followables: followables,
  locations: SlLocations.all,
  notifications: notifications,
  ads: ads,
  weather: weather,
  standings: standings,
);

/// A [FeedSource] whose outcome is scripted by the test.
class FakeFeedSource implements FeedSource {
  /// Creates a source for [config].
  FakeFeedSource({
    required this.config,
    this.articles = const <Article>[],
    this.error,
    this.delay = Duration.zero,
    this.onFetch,
  });

  @override
  final FeedSourceConfig config;

  /// Articles returned when [error] is null.
  final List<Article> articles;

  /// Thrown instead of returning articles.
  final Object? error;

  /// Held open before answering, so timeout behaviour can be exercised.
  final Duration delay;

  /// Called at the start of every fetch, for counting or for flipping results.
  final void Function()? onFetch;

  /// How many times [fetch] was called.
  int fetchCount = 0;

  @override
  Future<List<Article>> fetch({int limit = 20}) async {
    fetchCount++;
    onFetch?.call();
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final Object? failure = error;
    if (failure != null) throw failure;
    return articles.length > limit ? articles.sublist(0, limit) : articles;
  }
}

/// A Dio adapter that answers from [responder] and records the requests.
class FakeHttpAdapter implements HttpClientAdapter {
  /// Creates an adapter driven by [responder].
  FakeHttpAdapter(this.responder);

  /// Produces the response for each request.
  final Future<ResponseBody> Function(RequestOptions options) responder;

  /// Every request the client made, in order.
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Wires [responder] into a real [Dio] and returns both halves.
({Dio dio, FakeHttpAdapter adapter}) dioWith(
  Future<ResponseBody> Function(RequestOptions) responder,
) {
  final FakeHttpAdapter adapter = FakeHttpAdapter(responder);
  final Dio dio = Dio()..httpClientAdapter = adapter;
  return (dio: dio, adapter: adapter);
}

/// A 200 JSON response body.
ResponseBody jsonBody(String text, {int statusCode = 200}) =>
    ResponseBody.fromString(
      text,
      statusCode,
      headers: <String, List<String>>{
        'content-type': <String>['application/json; charset=utf-8'],
      },
    );
