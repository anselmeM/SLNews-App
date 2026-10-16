import 'package:flutter/foundation.dart';

/// A news outlet or wire service that SLNews aggregates.
@immutable
class Publisher {
  const Publisher({
    required this.id,
    required this.name,
    this.wordmark,
    this.logoUrl,
    this.websiteUrl,
    this.country = 'Sierra Leone',
    this.isWire = false,
  });

  /// Stable slug, e.g. `awoko`.
  final String id;

  /// Display name, e.g. "Awoko Newspaper".
  final String name;

  /// Short uppercase mark drawn when no logo asset is available, e.g. "AWOKO".
  final String? wordmark;

  final String? logoUrl;
  final String? websiteUrl;
  final String country;

  /// Wire services are labelled and shown without a follow toggle.
  final bool isWire;

  String get mark => wordmark ?? name.toUpperCase();

  Publisher copyWith({
    String? name,
    String? wordmark,
    String? logoUrl,
    String? websiteUrl,
  }) {
    return Publisher(
      id: id,
      name: name ?? this.name,
      wordmark: wordmark ?? this.wordmark,
      logoUrl: logoUrl ?? this.logoUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      country: country,
      isWire: isWire,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'wordmark': wordmark,
    'logoUrl': logoUrl,
    'websiteUrl': websiteUrl,
    'country': country,
    'isWire': isWire,
  };

  factory Publisher.fromJson(Map<String, dynamic> json) => Publisher(
    id: json['id'] as String,
    name: json['name'] as String,
    wordmark: json['wordmark'] as String?,
    logoUrl: json['logoUrl'] as String?,
    websiteUrl: json['websiteUrl'] as String?,
    country: json['country'] as String? ?? 'Sierra Leone',
    isWire: json['isWire'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is Publisher &&
      other.id == id &&
      other.name == name &&
      other.wordmark == wordmark &&
      other.logoUrl == logoUrl &&
      other.websiteUrl == websiteUrl &&
      other.country == country &&
      other.isWire == isWire;

  @override
  int get hashCode =>
      Object.hash(id, name, wordmark, logoUrl, websiteUrl, country, isWire);
}
