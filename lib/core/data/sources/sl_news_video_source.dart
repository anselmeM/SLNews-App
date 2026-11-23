import 'package:flutter/foundation.dart';

import '../../domain/models/video_moment.dart';
import 'api_client.dart';
import 'sl_news_api_source.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

/// Reads the "Video moments" rail from the scraper's `/v1/videos` endpoint.
///
/// The same key and host as the news source are reused, so a build configured
/// for content gets videos for free. When the endpoint is empty or unavailable,
/// [VideoMomentsController] keeps the bundled [SlVideos] rotation visible so the
/// rail never disappears from the home screen.
class SlNewsVideoSource {
  /// Creates a source over the shared API client.
  /// Positional formals because the fields are private and named parameters
  /// cannot use `this._field`.
  SlNewsVideoSource(this._config, this._api);

  final SlNewsApiConfig _config;
  final ApiClient _api;

  /// True when the build has a host and key.
  bool get isConfigured => _config.isConfigured;

  /// Path of the versioned endpoint. `/v1` is a business contract with no legacy
  /// twin: videos are newer than `/api/v1`, so there is nothing to fall back to.
  static const String path = '/v1/videos';

  /// Public read-only variant used when the reader has no session token.
  static const String publicPath = '/v1/public/videos';

  /// Newest videos, or an empty list when unconfigured, empty or failing.
  ///
  /// Never throws: the feed page must render whether or not the rail has data.
  Future<List<VideoMoment>> latest({int limit = 8}) async {
    if (!isConfigured) return const <VideoMoment>[];

    final String base = _config.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final int pageSize = limit.clamp(1, 100);

    try {
      // The rail is decorative: never let a cold Render instance delay the
      // reader for the client-wide 8s timeout.
      // A key-less build authenticates with the Clerk session token, which
      // ApiClient attaches to the allow-listed scraper host. Sending an empty
      // "Bearer " here would override that token and 401 the request.
      final String key = _config.apiKey.trim();
      final ApiResponse response;
      try {
        response = await _api
            .get(
              '$base$path?page_size=$pageSize',
              headers: key.isEmpty
                  ? null
                  : <String, String>{'Authorization': 'Bearer $key'},
            )
            .timeout(const Duration(seconds: 4));
      } on ApiException catch (error) {
        if (error.statusCode != 401 && error.statusCode != 403) rethrow;
        // Anonymous readers and expired sessions use the public read-only rail.
        final ApiResponse publicResponse = await _api
            .get('$base$publicPath?page_size=$pageSize')
            .timeout(const Duration(seconds: 4));
        return parse(publicResponse.data).take(limit).toList(growable: false);
      }
      return parse(response.data).take(limit).toList(growable: false);
    } catch (error) {
      AppLog.debug('SlNewsVideoSource: /v1/videos unavailable ($error)');
      return const <VideoMoment>[];
    }
  }

  /// Extracts the payload's `data[]`, skipping rows without an identity.
  @visibleForTesting
  static List<VideoMoment> parse(Object? payload) {
    if (payload is! Map) return const <VideoMoment>[];
    final Object? rows = payload['data'];
    if (rows is! List) return const <VideoMoment>[];

    final List<VideoMoment> videos = <VideoMoment>[];
    for (final Object? row in rows) {
      if (row is! Map) continue;
      final VideoMoment video = VideoMoment.fromJson(
        row.map<String, dynamic>(
          (Object? key, Object? value) =>
              MapEntry<String, dynamic>('$key', value),
        ),
      );
      if (video.id.isEmpty || video.title.isEmpty) continue;
      videos.add(video);
    }

    videos.sort((VideoMoment a, VideoMoment b) {
      final DateTime instantA =
          a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final DateTime instantB =
          b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      return instantB.compareTo(instantA);
    });
    return videos;
  }
}
