import 'package:flutter/foundation.dart';

/// Everything the Following tab lets a reader subscribe to.
enum FollowKind {
  team,
  league,
  location,
  topic,
  publisher;

  static FollowKind fromWire(String? raw) => switch (raw?.toLowerCase()) {
    'team' => FollowKind.team,
    'league' => FollowKind.league,
    'location' => FollowKind.location,
    'publisher' => FollowKind.publisher,
    _ => FollowKind.topic,
  };

  String get wireValue => name;

  /// Section header for grouped lists in the Following tab.
  String get sectionLabel => switch (this) {
    FollowKind.team || FollowKind.league => 'Sports',
    FollowKind.location => 'Locations',
    FollowKind.topic => 'Topics',
    FollowKind.publisher => 'Publishers',
  };
}

/// A followable entity (team, league, city, topic or publisher).
@immutable
class FollowTarget {
  const FollowTarget({
    required this.id,
    required this.kind,
    required this.label,
    this.subtitle,
    this.imageUrl,
    this.emojiOrGlyph,
    this.isPopular = false,
  });

  /// Globally unique id; prefixed by kind in seed data (`team:lal`, `city:freetown`).
  final String id;

  final FollowKind kind;
  final String label;

  /// Secondary line, e.g. "Basketball · NBA" or "Sierra Leone".
  final String? subtitle;

  /// Crest / avatar for teams and publishers.
  final String? imageUrl;

  /// Material icon key resolved by `FollowGlyph` when no image is available.
  final String? emojiOrGlyph;

  /// Surfaced in "Most popular with users".
  final bool isPopular;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'kind': kind.wireValue,
    'label': label,
    'subtitle': subtitle,
    'imageUrl': imageUrl,
    'emojiOrGlyph': emojiOrGlyph,
    'isPopular': isPopular,
  };

  factory FollowTarget.fromJson(Map<String, dynamic> json) => FollowTarget(
    id: json['id'] as String,
    kind: FollowKind.fromWire(json['kind'] as String?),
    label: json['label'] as String,
    subtitle: json['subtitle'] as String?,
    imageUrl: json['imageUrl'] as String?,
    emojiOrGlyph: json['emojiOrGlyph'] as String?,
    isPopular: json['isPopular'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is FollowTarget && other.id == id && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, kind);
}

/// Immutable snapshot of the reader's subscriptions, grouped for display.
@immutable
class FollowingSnapshot {
  const FollowingSnapshot({
    required this.followed,
    required this.suggested,
    this.sports = const <FollowTarget>[],
    this.locations = const <FollowTarget>[],
    this.topics = const <FollowTarget>[],
    this.publishers = const <FollowTarget>[],
  });

  const FollowingSnapshot.empty()
    : followed = const <FollowTarget>[],
      suggested = const <FollowTarget>[],
      sports = const <FollowTarget>[],
      locations = const <FollowTarget>[],
      topics = const <FollowTarget>[],
      publishers = const <FollowTarget>[];

  /// Everything the reader currently follows.
  final List<FollowTarget> followed;

  /// "Most popular with users" suggestions with a Follow chip.
  final List<FollowTarget> suggested;

  final List<FollowTarget> sports;
  final List<FollowTarget> locations;
  final List<FollowTarget> topics;
  final List<FollowTarget> publishers;

  List<String> get followedIds =>
      followed.map((FollowTarget t) => t.id).toList(growable: false);

  bool isFollowed(String id) => followed.any((FollowTarget t) => t.id == id);

  FollowingSnapshot copyWith({
    List<FollowTarget>? followed,
    List<FollowTarget>? suggested,
    List<FollowTarget>? sports,
    List<FollowTarget>? locations,
    List<FollowTarget>? topics,
    List<FollowTarget>? publishers,
  }) {
    return FollowingSnapshot(
      followed: followed ?? this.followed,
      suggested: suggested ?? this.suggested,
      sports: sports ?? this.sports,
      locations: locations ?? this.locations,
      topics: topics ?? this.topics,
      publishers: publishers ?? this.publishers,
    );
  }
}

/// A saved location used for the localised feed and weather header.
@immutable
class NewsLocation {
  const NewsLocation({
    required this.id,
    required this.label,
    required this.region,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String label;
  final String region;
  final double? latitude;
  final double? longitude;

  /// "Freetown, SL" style subtitle.
  String get subtitle => region;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'region': region,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory NewsLocation.fromJson(Map<String, dynamic> json) => NewsLocation(
    id: json['id'] as String,
    label: json['label'] as String,
    region: json['region'] as String? ?? 'Sierra Leone',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );

  @override
  bool operator ==(Object other) => other is NewsLocation && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The cities SLNews ships as defaults, with Freetown as the home market.
abstract final class SlLocations {
  static const List<NewsLocation> all = <NewsLocation>[
    NewsLocation(
      id: 'city:freetown',
      label: 'Freetown',
      region: 'Western Area',
      latitude: 8.484,
      longitude: -13.2299,
    ),
    NewsLocation(
      id: 'city:bo',
      label: 'Bo',
      region: 'Southern Province',
      latitude: 7.9647,
      longitude: -11.7383,
    ),
    NewsLocation(
      id: 'city:kenema',
      label: 'Kenema',
      region: 'Eastern Province',
      latitude: 7.8767,
      longitude: -11.1903,
    ),
    NewsLocation(
      id: 'city:makeni',
      label: 'Makeni',
      region: 'Northern Province',
      latitude: 8.8861,
      longitude: -12.0442,
    ),
    NewsLocation(
      id: 'city:koidu',
      label: 'Koidu',
      region: 'Kono District',
      latitude: 8.6439,
      longitude: -10.9711,
    ),
  ];

  static const NewsLocation fallback = NewsLocation(
    id: 'city:freetown',
    label: 'Freetown',
    region: 'Western Area',
    latitude: 8.484,
    longitude: -13.2299,
  );
}
