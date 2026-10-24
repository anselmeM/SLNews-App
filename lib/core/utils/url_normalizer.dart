/// URL hygiene shared by the ingestion and cache layers.
///
/// Feed links arrive relative, decorated with tracking parameters and with
/// mixed-case hosts. Normalising them in one place keeps article identity
/// stable (`StableId`) and stops the same story being cached under two URLs.
abstract final class UrlNormalizer {
  /// Image URL safe for Android/iOS: absolute https only.
  ///
  /// Feeds still advertise `http://` images; Android blocks cleartext, which is
  /// why some thumbnails rendered blank. Upgrading the scheme is enough for
  /// every publisher we ingest (their hosts serve TLS).
  static String? secureImage(String? candidate) {
    final String? absoluteUrl = candidate?.trim();
    if (absoluteUrl == null || absoluteUrl.isEmpty) return null;
    final String lowered = absoluteUrl.toLowerCase();
    if (lowered.startsWith('http://')) {
      return 'https://${absoluteUrl.substring(7)}';
    }
    if (lowered.startsWith('https://')) return absoluteUrl;
    return null;
  }

  /// Query parameters that identify a campaign, never a resource.
  static const Set<String> _trackingKeys = <String>{'fbclid', 'gclid'};

  /// Canonical form of [url] used for de-duplication and stable ids.
  ///
  /// Lowercases the scheme and host, drops the fragment, removes tracking
  /// parameters, sorts the remaining query and strips trailing slashes.
  /// Unparseable input is normalised textually rather than rejected, because a
  /// feed typo must not empty the reader's feed.
  static String canonical(String url) {
    final String trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    String working = _stripFragment(trimmed);
    working = _stripTracking(working);
    working = _stripTrailingSlashes(working);
    return _lowercaseAuthority(working);
  }

  /// Resolves [candidate] against [base], or `null` when it cannot be an
  /// absolute http(s) URL.
  ///
  /// Feeds mix absolute links, site-relative paths and protocol-relative URLs;
  /// returning `null` lets callers fall back instead of inventing a URL.
  static String? absolute(String? candidate, {required String base}) {
    final String raw = candidate?.trim() ?? '';
    if (raw.isEmpty) return null;

    final String lowered = raw.toLowerCase();
    if (lowered.startsWith('http://') || lowered.startsWith('https://')) {
      return hostLabel(raw).isEmpty ? null : canonical(raw);
    }

    final Uri baseUri;
    try {
      baseUri = Uri.parse(base.trim());
    } on FormatException {
      return null;
    }
    if (baseUri.host.isEmpty) return null;

    try {
      final Uri resolved = baseUri.resolve(raw);
      final String scheme = resolved.scheme.toLowerCase();
      if (scheme != 'http' && scheme != 'https') return null;
      if (resolved.host.isEmpty) return null;
      return canonical(resolved.toString());
    } on FormatException {
      // A malformed link is dropped; the caller keeps the feed's own URL.
      return null;
    }
  }

  /// Readable host for attributions such as "via awoko.org".
  ///
  /// Accepts bare hosts (`awoko.org/news`) as well as full URLs and strips a
  /// leading `www.` so wordmarks read cleanly.
  static String hostLabel(String url) {
    final String trimmed = url.trim();
    if (trimmed.isEmpty) return '';

    String host = '';
    try {
      host = Uri.parse(trimmed).host;
    } on FormatException {
      host = '';
    }

    if (host.isEmpty) {
      final String withoutScheme = trimmed.contains('://')
          ? trimmed.substring(trimmed.indexOf('://') + 3)
          : trimmed;
      final String authority = withoutScheme.split('/').first.split('?').first;
      final int at = authority.lastIndexOf('@');
      host = at < 0 ? authority : authority.substring(at + 1);
      final int colon = host.indexOf(':');
      if (colon >= 0 && !host.startsWith('[')) {
        host = host.substring(0, colon);
      }
    }

    final String lower = host.toLowerCase();
    return lower.startsWith('www.') ? lower.substring(4) : lower;
  }

  static String _stripFragment(String value) {
    final int hash = value.indexOf('#');
    return hash < 0 ? value : value.substring(0, hash);
  }

  static String _stripTracking(String value) {
    final int query = value.indexOf('?');
    if (query < 0) return value;

    final String head = value.substring(0, query);
    final String rawQuery = value.substring(query + 1);
    if (rawQuery.isEmpty) return head;

    final List<String> kept = <String>[];
    for (final String pair in rawQuery.split('&')) {
      if (pair.isEmpty) continue;
      if (_isTracking(_queryKey(pair))) continue;
      kept.add(pair);
    }
    if (kept.isEmpty) return head;

    kept.sort(_compareQueryPairs);
    return '$head?${kept.join('&')}';
  }

  static bool _isTracking(String rawKey) {
    final String key = _safeDecodeQueryComponent(rawKey).toLowerCase();
    return _trackingKeys.contains(key) || key.startsWith('utm_');
  }

  static String _safeDecodeQueryComponent(String value) {
    try {
      return Uri.decodeQueryComponent(value);
    } on ArgumentError {
      return value;
    }
  }

  static String _queryKey(String pair) {
    final int equals = pair.indexOf('=');
    return (equals < 0 ? pair : pair.substring(0, equals)).toLowerCase();
  }

  static int _compareQueryPairs(String a, String b) {
    final int byKey = _queryKey(a).compareTo(_queryKey(b));
    return byKey != 0 ? byKey : a.compareTo(b);
  }

  static String _stripTrailingSlashes(String value) {
    if (value.endsWith('://')) return value;
    String working = value;
    while (working.length > 1 && working.endsWith('/')) {
      working = working.substring(0, working.length - 1);
    }
    return working == '/' ? '' : working;
  }

  static String _lowercaseAuthority(String value) {
    final int schemeEnd = value.indexOf('://');
    if (schemeEnd <= 0) return value;

    final String scheme = value.substring(0, schemeEnd).toLowerCase();
    final String rest = value.substring(schemeEnd + 3);
    final int pathStart = rest.indexOf('/');
    final String authority = pathStart < 0
        ? rest
        : rest.substring(0, pathStart);
    final String path = pathStart < 0 ? '' : rest.substring(pathStart);

    final int at = authority.lastIndexOf('@');
    final String userInfo = at < 0 ? '' : authority.substring(0, at + 1);
    final String hostPort = at < 0 ? authority : authority.substring(at + 1);
    return '$scheme://$userInfo${_lowercaseHostPort(hostPort)}$path';
  }

  static String _lowercaseHostPort(String hostPort) {
    final String lower = hostPort.toLowerCase();
    for (final String defaultPort in const <String>[':80', ':443']) {
      if (!lower.endsWith(defaultPort)) continue;
      final String host = lower.substring(0, lower.length - defaultPort.length);
      // A colon that survives belongs to an IPv6 literal; keep its port.
      if (!host.contains(':')) return host;
    }
    return lower;
  }
}
