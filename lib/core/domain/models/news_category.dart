import 'package:flutter/foundation.dart';

/// A filter pill in the News tab's horizontal category bar.
@immutable
class NewsCategory {
  const NewsCategory({
    required this.id,
    required this.label,
    this.icon = 'topic',
    this.isDefault = false,
  });

  /// Slug used in routes and in `FollowTarget` records, e.g. `politics`.
  final String id;

  /// Display label, e.g. "Politics".
  final String label;

  /// Icon key resolved by `CategoryIcon` in the design system.
  final String icon;

  /// Part of the always-visible pill strip.
  final bool isDefault;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'icon': icon,
    'isDefault': isDefault,
  };

  factory NewsCategory.fromJson(Map<String, dynamic> json) => NewsCategory(
    id: json['id'] as String,
    label: json['label'] as String,
    icon: json['icon'] as String? ?? 'topic',
    isDefault: json['isDefault'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is NewsCategory && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// The curated SLNews category set, ordered as it appears in the pill strip.
abstract final class NewsCategories {
  static const List<NewsCategory> all = <NewsCategory>[
    NewsCategory(id: 'top', label: 'Top stories', icon: 'top', isDefault: true),
    NewsCategory(
      id: 'politics',
      label: 'Politics',
      icon: 'politics',
      isDefault: true,
    ),
    NewsCategory(
      id: 'business',
      label: 'Business',
      icon: 'business',
      isDefault: true,
    ),
    NewsCategory(id: 'cars', label: 'Cars and Vehicles', icon: 'cars'),
    NewsCategory(id: 'music', label: 'Music', icon: 'music'),
    NewsCategory(id: 'culture', label: 'Culture', icon: 'culture'),
    NewsCategory(id: 'sports', label: 'Sports', icon: 'sports'),
    NewsCategory(id: 'health', label: 'Health', icon: 'health'),
    NewsCategory(id: 'tech', label: 'Tech', icon: 'tech'),
    NewsCategory(id: 'education', label: 'Education', icon: 'education'),
    NewsCategory(id: 'mining', label: 'Mining', icon: 'mining'),
    NewsCategory(id: 'world', label: 'World', icon: 'world'),
  ];

  static NewsCategory byId(String id) =>
      all.firstWhere((NewsCategory c) => c.id == id, orElse: () => all.first);
}
