import 'package:flutter/foundation.dart';

/// How a [VideoMoment] URL can actually be played inside the app.
///
/// The scraper and the bundled seed both hand out whatever URL the outlet
/// publishes: a YouTube link for broadcaster clips, or the story page itself.
/// Opening those in an external browser breaks the reel experience the reference
/// has, so they are classified here and the reel page decides how to present each.
enum VideoPlaybackKind {
  /// A YouTube video: played through the embedded player.
  youtube,

  /// Any other web page: shown in-app, inside the reel's own web view.
  web,

  /// Nothing playable (empty or non-http URL): the reel shows the thumbnail.
  unsupported,
}

@immutable
class VideoPlayback {
  const VideoPlayback({
    required this.kind,
    required this.uri,
    this.embedUrl,
    this.externalUrl,
    this.youtubeId,
  });

  final VideoPlaybackKind kind;

  /// Local thumbnail or the web page to show.
  final Uri? uri;

  /// URL to load inside the embedded player, for [VideoPlaybackKind.youtube].
  final String? embedUrl;

  /// Original URL, for "open in browser".
  final String? externalUrl;

  /// Extracted YouTube id, when this is a YouTube link.
  final String? youtubeId;

  bool get isPlayable => kind != VideoPlaybackKind.unsupported;
}

/// YouTube's privacy-friendly player, with inline playback for a web view.
///
/// `playsinline=1` keeps iOS from going full-screen, `rel=0` hides unrelated
/// videos and `modestbranding=1` keeps the chrome minimal — the reference player
/// shows only the clip. `mute=1` is deliberate: the reel starts muted so
/// autoplay is allowed on every platform, and the reader unmutes from the rail.
String youTubeEmbedUrl(String id) =>
    'https://www.youtube-nocookie.com/embed/$id'
    '?autoplay=1&mute=1&playsinline=1&rel=0&modestbranding=1&controls=1';

/// Extracts the video id from every YouTube URL shape the outlets use.
String? youTubeIdFrom(String rawUrl) {
  final Uri? uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || !uri.hasScheme) return null;

  final String host = uri.host.toLowerCase();
  final bool youtubeHost =
      host == 'youtube.com' ||
      host == 'www.youtube.com' ||
      host == 'm.youtube.com' ||
      host == 'youtu.be' ||
      host == 'youtube-nocookie.com' ||
      host == 'www.youtube-nocookie.com' ||
      host.endsWith('.youtube.com');
  if (!youtubeHost) return null;

  if (host == 'youtu.be') {
    final String id = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    return _validId(id);
  }

  final String? queryId = uri.queryParameters['v'];
  if (queryId != null) return _validId(queryId);

  final List<String> segments = uri.pathSegments;
  for (int index = 0; index < segments.length - 1; index++) {
    final String segment = segments[index];
    if (segment == 'shorts' || segment == 'embed' || segment == 'v') {
      return _validId(segments[index + 1]);
    }
  }
  return null;
}

/// YouTube ids are 11 characters of `[A-Za-z0-9_-]`.
String? _validId(String candidate) {
  final String id = candidate.trim();
  if (id.length != 11) return null;
  return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id) ? id : null;
}

/// Classifies a moment's URL for playback.
VideoPlayback resolvePlayback(String rawUrl, {String? knownId}) {
  final String url = rawUrl.trim();
  final Uri? uri = Uri.tryParse(url);
  if (uri == null ||
      !uri.hasScheme ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return VideoPlayback(kind: VideoPlaybackKind.unsupported, uri: null);
  }

  final String? id = youTubeIdFrom(url);
  if (id != null) {
    return VideoPlayback(
      kind: VideoPlaybackKind.youtube,
      uri: uri,
      embedUrl: youTubeEmbedUrl(id),
      externalUrl: url,
      youtubeId: id,
    );
  }

  final String? fallbackId = knownId == null ? null : _validId(knownId);
  if (fallbackId != null) {
    return VideoPlayback(
      kind: VideoPlaybackKind.youtube,
      uri: uri,
      embedUrl: youTubeEmbedUrl(fallbackId),
      externalUrl: 'https://www.youtube.com/watch?v=$fallbackId',
      youtubeId: fallbackId,
    );
  }

  // A YouTube URL that is not a video (channel, @handle, search, playlist).
  // Loading it in the reel's web view shows a channel profile or a search page
  // instead of a clip — exactly the behaviour the rail must never produce.
  // Keep the URL for "Open in browser" but do not pretend it is playable.
  if (_isYouTubeHost(uri.host)) {
    return VideoPlayback(
      kind: VideoPlaybackKind.unsupported,
      uri: null,
      externalUrl: url,
    );
  }

  return VideoPlayback(
    kind: VideoPlaybackKind.web,
    uri: uri,
    embedUrl: url,
    externalUrl: url,
  );
}

bool _isYouTubeHost(String rawHost) {
  final String host = rawHost.toLowerCase();
  return host == 'youtu.be' ||
      host == 'youtube.com' ||
      host == 'www.youtube.com' ||
      host == 'm.youtube.com' ||
      host.endsWith('.youtube.com') ||
      host == 'youtube-nocookie.com' ||
      host == 'www.youtube-nocookie.com';
}
