import 'package:flutter/foundation.dart';

/// Where the SLNews mobile sync API lives.
///
/// Compile-time configuration only — there is no runtime switch, because a build
/// either ships pointed at a sync backend or it does not ship sync at all:
///
/// ```powershell
/// # Production: the PWA origin (Next.js route handlers live here).
/// flutter run
///
/// # Vercel preview / staging deployment of the PWA: the preview origin is
/// # per-deployment, so it must be passed explicitly.
/// flutter run --dart-define=SLNEWS_SYNC_URL=https://slnews-git-sync-xyz.vercel.app
///
/// # Local development against `next dev`.
/// flutter run --dart-define=SLNEWS_SYNC_URL=http://10.0.2.2:3000
///
/// # Explicitly disabled, even if a default existed.
/// flutter build apk --dart-define=SLNEWS_SYNC_URL=
/// ```
///
/// An empty `SLNEWS_SYNC_URL` means "no sync": [isConfigured] is `false`, the
/// repository reports itself unconfigured and neither `pull` nor `push` performs
/// I/O. That is how an unconfigured build keeps behaving exactly like today's
/// local-only app.
@immutable
class SyncApiConfig {
  /// Creates a configuration for an explicitly supplied origin.
  const SyncApiConfig({
    required this.baseUrl,
    this.limit = defaultLimit,
  });

  /// Reads compile-time configuration:
  ///   `--dart-define=SLNEWS_SYNC_URL=…`  (default: [defaultBaseUrl])
  ///   `--dart-define=SLNEWS_SYNC_LIMIT=…`
  factory SyncApiConfig.fromEnvironment() {
    const String url = String.fromEnvironment(
      'SLNEWS_SYNC_URL',
      defaultValue: defaultBaseUrl,
    );
    const String rawLimit = String.fromEnvironment('SLNEWS_SYNC_LIMIT');
    return SyncApiConfig(
      baseUrl: url,
      limit: clampLimit(int.tryParse(rawLimit.trim()) ?? defaultLimit),
    );
  }

  /// The PWA origin: the Next.js route handlers that serve `/api/mobile/v1/sync`
  /// are deployed with the web app, so a default build syncs with production.
  static const String defaultBaseUrl = 'https://slnews.sl';

  /// Rows per collection requested on a pull; the API's own default.
  static const int defaultLimit = 500;

  /// Lower bound the API accepts for `limit`.
  static const int minLimit = 1;

  /// Upper bound the API accepts for `limit` (`413` above it).
  static const int maxLimit = 500;

  /// Origin plus optional path prefix, e.g. `https://slnews.sl`. Never has a
  /// trailing slash, because [endpoint] concatenates the path directly.
  final String baseUrl;

  /// `limit` sent on pulls; clamped to `1..500`.
  final int limit;

  /// True only when an origin was supplied.
  bool get isConfigured => baseUrl.trim().isNotEmpty;

  /// Host that may receive the session token.
  ///
  /// `ApiClient` attaches a Clerk JWT only to allow-listed hosts, so this is the
  /// value the composition root must add to `authTokenHosts`; without it the
  /// sync request goes out unauthenticated and the API answers `401`.
  String get host {
    final String trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return '';
    final Uri? uri = Uri.tryParse(trimmed);
    final String host = uri?.host ?? '';
    return host.isNotEmpty ? host : trimmed;
  }

  /// Full URL of the sync endpoint, e.g. `https://slnews.sl/api/mobile/v1/sync`.
  String get endpoint => '${_normalize(baseUrl)}$syncPath';

  /// Copy of this configuration with the given fields replaced.
  SyncApiConfig copyWith({String? baseUrl, int? limit}) => SyncApiConfig(
    baseUrl: baseUrl ?? this.baseUrl,
    limit: limit == null ? this.limit : clampLimit(limit),
  );

  /// Clamps [value] into the range the API accepts.
  static int clampLimit(int value) => value < minLimit
      ? minLimit
      : (value > maxLimit ? maxLimit : value);

  @override
  String toString() =>
      'SyncApiConfig(${host.isEmpty ? '<unset>' : host}, '
      'limit: $limit, ${isConfigured ? 'enabled' : 'disabled'})';

  static String _normalize(String value) {
    String working = value.trim();
    while (working.endsWith('/')) {
      working = working.substring(0, working.length - 1);
    }
    return working;
  }

  /// Base path of the mobile API; the sync endpoint is the only route v1 needs.
  static const String apiPath = '/api/mobile/v1';

  /// Path of the batched GET (delta pull) and POST (batched push).
  static const String syncPath = '$apiPath/sync';
}
