import '../../domain/models/article.dart';
import 'api_client.dart';
import 'feed_source.dart';
import 'json_article_mapper.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

/// Reader for a plain REST endpoint that returns articles as JSON.
///
/// Accepts a bare array or an envelope (`items`, `articles`, `data`, `results`)
/// and derives anything the payload omits from the outlet configuration.
class RestApiSource implements FeedSource {
  /// Creates a reader for [config] fetching through [client].
  RestApiSource({required this.config, required ApiClient client})
    : _api = client;

  @override
  final FeedSourceConfig config;

  final ApiClient _api;

  @override
  Future<List<Article>> fetch({int limit = 20}) async {
    try {
      final Object? payload = await _api.getJson(config.url);
      return JsonArticleMapper.toArticles(payload, config, limit: limit);
    } catch (error) {
      AppLog.debug('RestApiSource(${config.id}): $error');
      return const <Article>[];
    }
  }
}
