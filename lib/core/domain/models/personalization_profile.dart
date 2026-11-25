import 'package:flutter/foundation.dart';

/// One local engagement signal used by For You personalization.
enum EngagementKind {
  open,
  read,
  save,
  like,
  skip,
  dismiss;

  String get wireValue => name;

  static EngagementKind fromWire(String? value) => switch (value) {
    'open' => EngagementKind.open,
    'read' => EngagementKind.read,
    'save' => EngagementKind.save,
    'like' => EngagementKind.like,
    'skip' => EngagementKind.skip,
    'dismiss' => EngagementKind.dismiss,
    _ => EngagementKind.open,
  };
}

/// A single on-device affinity event.
@immutable
class EngagementEvent {
  const EngagementEvent({
    required this.articleId,
    required this.topicId,
    required this.publisherId,
    required this.kind,
    required this.at,
    required this.weight,
    this.progress,
    this.dwellSeconds,
  });

  final String articleId;
  final String topicId;
  final String publisherId;
  final EngagementKind kind;
  final DateTime at;
  final double weight;
  final double? progress;
  final int? dwellSeconds;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'articleId': articleId,
    'topicId': topicId,
    'publisherId': publisherId,
    'kind': kind.wireValue,
    'at': at.toIso8601String(),
    'weight': weight,
    'progress': progress,
    'dwellSeconds': dwellSeconds,
  };

  factory EngagementEvent.fromJson(Map<String, dynamic> json) =>
      EngagementEvent(
        articleId: json['articleId'] as String? ?? '',
        topicId: json['topicId'] as String? ?? '',
        publisherId: json['publisherId'] as String? ?? '',
        kind: EngagementKind.fromWire(json['kind'] as String?),
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
        weight: (json['weight'] as num?)?.toDouble() ?? 0,
        progress: (json['progress'] as num?)?.toDouble(),
        dwellSeconds: (json['dwellSeconds'] as num?)?.toInt(),
      );
}

/// Reading position of one article on this device.
@immutable
class ReadingProgressEntry {
  const ReadingProgressEntry({
    required this.articleId,
    required this.progress,
    required this.lastReadAt,
  });

  final String articleId;
  final double progress;
  final DateTime lastReadAt;

  bool get isUnfinished => progress >= 0.05 && progress < 0.9;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'articleId': articleId,
    'progress': progress,
    'lastReadAt': lastReadAt.toIso8601String(),
  };

  factory ReadingProgressEntry.fromJson(Map<String, dynamic> json) =>
      ReadingProgressEntry(
        articleId: json['articleId'] as String? ?? '',
        progress: ((json['progress'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
        lastReadAt:
            DateTime.tryParse(json['lastReadAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Persistent, device-local engagement profile.
///
/// Kept as a small event log (not a server profile) so 7/30-day affinity can be
/// recomputed and the reader can reset it from Settings. Nothing here is
/// synchronized or sent to the backend.
@immutable
class PersonalizationProfile {
  const PersonalizationProfile({
    this.events = const <EngagementEvent>[],
    this.progress = const <String, ReadingProgressEntry>{},
  });

  static const int maxEvents = 500;
  static const int maxProgressEntries = 80;
  static const Duration eventWindow = Duration(days: 30);

  final List<EngagementEvent> events;
  final Map<String, ReadingProgressEntry> progress;

  bool get isEmpty => events.isEmpty && progress.isEmpty;

  int get eventCount => events.length;

  int get unfinishedCount => progress.values
      .where((ReadingProgressEntry entry) => entry.isUnfinished)
      .length;

  /// Articles hidden by an explicit "Show less like this" within the window.
  Set<String> dismissedArticleIds({DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    return <String>{
      for (final EngagementEvent event in events)
        if (event.kind == EngagementKind.dismiss &&
            reference.difference(event.at) <= eventWindow)
          event.articleId,
    };
  }

  /// Unfinished, recent articles ordered by last read time.
  List<ReadingProgressEntry> continueReading({DateTime? now, int limit = 5}) {
    final DateTime reference = now ?? DateTime.now();
    final List<ReadingProgressEntry> candidates =
        progress.values
            .where(
              (ReadingProgressEntry entry) =>
                  entry.isUnfinished &&
                  reference.difference(entry.lastReadAt) <= eventWindow,
            )
            .toList(growable: false)
          ..sort(
            (ReadingProgressEntry a, ReadingProgressEntry b) =>
                b.lastReadAt.compareTo(a.lastReadAt),
          );
    return candidates.take(limit).toList(growable: false);
  }

  /// Decayed topic affinity. Events inside 7 days count fully; 7–30 days are
  /// half-weight; older events are ignored.
  Map<String, double> topicAffinity({DateTime? now}) =>
      _affinity((EngagementEvent event) => event.topicId, now: now);

  /// Decayed publisher affinity.
  Map<String, double> publisherAffinity({DateTime? now}) =>
      _affinity((EngagementEvent event) => event.publisherId, now: now);

  Map<String, double> _affinity(
    String Function(EngagementEvent event) keyOf, {
    DateTime? now,
  }) {
    final DateTime reference = now ?? DateTime.now();
    final Map<String, double> result = <String, double>{};
    for (final EngagementEvent event in events) {
      final Duration age = reference.difference(event.at);
      if (age > eventWindow) continue;
      final double decay = age <= const Duration(days: 7) ? 1 : 0.5;
      final String key = keyOf(event).trim();
      if (key.isEmpty) continue;
      result[key] = (result[key] ?? 0) + event.weight * decay;
    }
    return result;
  }

  PersonalizationProfile copyWith({
    List<EngagementEvent>? events,
    Map<String, ReadingProgressEntry>? progress,
  }) => PersonalizationProfile(
    events: events ?? this.events,
    progress: progress ?? this.progress,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': 1,
    'events': events
        .map((EngagementEvent event) => event.toJson())
        .toList(growable: false),
    'progress': progress.values
        .map((ReadingProgressEntry entry) => entry.toJson())
        .toList(growable: false),
  };

  factory PersonalizationProfile.fromJson(Map<String, dynamic> json) {
    final List<EngagementEvent> events = <EngagementEvent>[];
    final Object? rawEvents = json['events'];
    if (rawEvents is List) {
      for (final Object? entry in rawEvents) {
        if (entry is! Map) continue;
        try {
          events.add(
            EngagementEvent.fromJson(Map<String, dynamic>.from(entry)),
          );
        } catch (_) {
          // A corrupt event is skipped; the rest of the profile survives.
        }
      }
    }
    final Map<String, ReadingProgressEntry> progress =
        <String, ReadingProgressEntry>{};
    final Object? rawProgress = json['progress'];
    if (rawProgress is List) {
      for (final Object? entry in rawProgress) {
        if (entry is! Map) continue;
        try {
          final ReadingProgressEntry item = ReadingProgressEntry.fromJson(
            Map<String, dynamic>.from(entry),
          );
          if (item.articleId.isNotEmpty) progress[item.articleId] = item;
        } catch (_) {
          // Ignore a corrupt progress entry.
        }
      }
    }
    return PersonalizationProfile(events: events, progress: progress);
  }
}
