import 'package:flutter/foundation.dart';

/// One entry in the "Video moments" rail.
///
/// Derived from the scraper's `/v1/videos` payload (`video_id`, `title`,
/// `summary`, `source`, `category`, `url`, `thumbnail_url`, `published_at`) with
/// bundled seed entries as the offline fallback, the same arrangement the article
/// pipeline uses.
@immutable
class VideoMoment {
  const VideoMoment({
    required this.id,
    required this.title,
    required this.source,
    required this.thumbnailUrl,
    required this.url,
    this.summary,
    this.category,
    this.publishedAt,
    this.duration,
  });

  /// Stable identity for keys and de-duplication.
  final String id;

  final String title;

  /// Publisher or channel name shown under the caption.
  final String source;

  /// Portrait thumbnail. Empty means "no image"; the card shows a placeholder.
  final String thumbnailUrl;

  /// Playback or article page for the video.
  final String url;

  final String? summary;
  final String? category;
  final DateTime? publishedAt;

  /// Clip length when the payload carries one (`duration_seconds`, or a
  /// "m:ss" `duration` string). Many rows have none, and the card shows no
  /// badge rather than inventing a time.
  final Duration? duration;

  /// Tolerates both the versioned payload and a seed entry.
  ///
  /// Unknown or missing fields degrade instead of throwing: one malformed row
  /// must not take down the rail.
  factory VideoMoment.fromJson(Map<String, dynamic> json) {
    final String id = _string(json['id'] ?? json['video_id']) ?? '';
    return VideoMoment(
      id: id,
      title: _string(json['title']) ?? '',
      source: _string(json['source'] ?? json['channel']) ?? 'SLNews',
      thumbnailUrl: _string(json['thumbnail_url'] ?? json['thumbnail']) ?? '',
      url: _string(json['url']) ?? '',
      summary: _string(json['summary'] ?? json['description']),
      category: _string(json['category']),
      publishedAt: _date(json['published_at'] ?? json['publishedAt']),
      duration: _duration(
        json['duration_seconds'] ?? json['durationSeconds'] ?? json['duration'],
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'source': source,
    'thumbnail_url': thumbnailUrl,
    'url': url,
    'summary': summary,
    'category': category,
    'published_at': publishedAt?.toUtc().toIso8601String(),
    'duration_seconds': duration?.inSeconds,
  };

  static String? _string(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static Duration? _duration(Object? value) {
    if (value is num) {
      final int seconds = value.round();
      return seconds > 0 ? Duration(seconds: seconds) : null;
    }
    if (value is String) {
      final String raw = value.trim();
      if (raw.isEmpty) return null;
      final int? asSeconds = int.tryParse(raw);
      if (asSeconds != null) {
        return asSeconds > 0 ? Duration(seconds: asSeconds) : null;
      }
      // "1:05" or "1:02:03"
      final List<String> parts = raw.split(':');
      if (parts.every((String part) => int.tryParse(part) != null)) {
        int total = 0;
        for (final String part in parts) {
          total = total * 60 + int.parse(part);
        }
        return total > 0 ? Duration(seconds: total) : null;
      }
      return null;
    }
    return null;
  }

  static DateTime? _date(Object? value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value > 100000000000 ? value.toInt() : value.toInt() * 1000,
        isUtc: true,
      );
    }
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }

  @override
  bool operator ==(Object other) => other is VideoMoment && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VideoMoment($id, $title)';
}
