/// Hosts the app claims for HTTPS App Links.
///
/// Must stay in step with three other places: the manifest placeholder
/// `deepLinkHost` in `android/app/build.gradle.kts`, the `host` in the HTTPS
/// intent filter, and the `sha256_cert_fingerprints` served from
/// `/.well-known/assetlinks.json`. `docs/APP-LINKS.md` is the checklist.
const Set<String> appLinkHosts = <String>{'slnews.sl'};

/// Maps a platform-supplied URI onto an internal route.
///
/// Internal navigation is always scheme-less (`/for_you`), so anything with a
/// scheme came from outside the app:
///
/// - `slnews://article/<id>` → `/article/<id>`
/// - `https://slnews.sl/article/<id>` → `/article/<id>`
///
/// Anything else is returned unchanged: the router then shows its not-found
/// page rather than inventing a destination for a link the app never promised.
Uri normalizeDeepLink(Uri uri) {
  if (uri.scheme.isEmpty) return uri;

  final String? first = uri.pathSegments.isEmpty
      ? null
      : uri.pathSegments.first;

  // Custom scheme: the article id is the first path segment. `pathSegments`
  // drops the leading slash, so `slnews://article/abc` yields ['abc'].
  if (uri.scheme == 'slnews' && uri.host == 'article' && first != null) {
    return _articleRoute(first, uri);
  }

  // Launcher shortcuts open a tab directly.
  if (uri.scheme == 'slnews') {
    switch (uri.host) {
      case 'search':
        return Uri(path: '/search');
      case 'saved':
        return Uri(path: '/saved');
      case 'following':
        return Uri(path: '/following');
    }
  }

  // HTTPS App Link: `https://<host>/article/<id>`.
  if (uri.scheme == 'https' &&
      appLinkHosts.contains(uri.host) &&
      uri.pathSegments.length >= 2 &&
      uri.pathSegments[0] == 'article') {
    return _articleRoute(uri.pathSegments[1], uri);
  }

  return uri;
}

Uri _articleRoute(String id, Uri source) =>
    Uri(path: '/article/$id', query: source.hasQuery ? source.query : null);
