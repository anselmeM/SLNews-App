import 'package:flutter/foundation.dart';

import '../../domain/models/article.dart';
import 'api_client.dart';
import 'feed_source.dart';
import 'json_article_mapper.dart';

/// Reader for arbitrary JSON endpoints, including GraphQL.
///
/// When [graphqlQuery] is set the query is POSTed; otherwise [query] is sent as
/// query-string parameters on a GET. Which key holds the article list is
/// configurable through [extractPaths] because no two outlets agree on it.
class JsonEndpointSource implements FeedSource {
  /// Creates a reader for [config] fetching through [client].
  JsonEndpointSource({
    required this.config,
    required ApiClient client,
    this.query,
    this.graphqlQuery,
    List<String>? extractPaths,
  }) : _api = client,
       _extractPaths = extractPaths ?? defaultExtractPaths;

  /// Envelope keys tried when the payload is not already a list.
  static const List<String> defaultExtractPaths = <String>[
    'items',
    'data.articles',
    'data.stories',
    'articles',
    'results',
    'data.items',
  ];

  @override
  final FeedSourceConfig config;

  /// Query-string parameters for the GET form (also sent as GraphQL variables).
  final Map<String, dynamic>? query;

  /// GraphQL query document; when non-null the request becomes a POST.
  final String? graphqlQuery;

  final List<String> _extractPaths;
  final ApiClient _api;

  @override
  Future<List<Article>> fetch({int limit = 20}) async {
    try {
      final String? document = graphqlQuery;
      final Object? payload = document == null
          ? await _api.getJson(config.url, query: query)
          : await _api.postJson(config.url, <String, dynamic>{
              'query': document,
              if (query != null && query!.isNotEmpty) 'variables': query,
            });
      return JsonArticleMapper.toArticles(
        payload,
        config,
        limit: limit,
        paths: _extractPaths,
      );
    } catch (error) {
      debugPrint('JsonEndpointSource(${config.id}): $error');
      return const <Article>[];
    }
  }
}
