import '../routing/app_routes.dart';

/// Maps a push payload (`{url, articleId, ...}`) to an in-app route.
///
/// The backend sends web-style paths (`/article/<id>`, `/video/<id>`,
/// `/top_stories`) because the same notification is also addressable in the web
/// admin. Anything unrecognised returns null so a malformed push simply opens
/// the app instead of navigating to a dead route.
String? pushRouteFor(Map<String, dynamic> data) {
  String read(String key) {
    final Object? value = data[key];
    return value is String ? value.trim() : '';
  }

  final String url = read('url');
  final String articleId = read('articleId');

  String? suffix(String prefix) {
    if (!url.startsWith(prefix)) return null;
    final String rest = url.substring(prefix.length);
    return rest.isEmpty ? null : rest;
  }

  final String? article = suffix('/article/');
  if (article != null) return AppRoutes.articleFor(article);
  final String? video = suffix('/video/');
  if (video != null) return AppRoutes.videoFor(video);
  final String? section = suffix('/section/');
  if (section != null) return AppRoutes.sectionFor(section);
  if (url == '/top_stories') return AppRoutes.topStories;
  if (articleId.isNotEmpty) return AppRoutes.articleFor(articleId);
  return null;
}
