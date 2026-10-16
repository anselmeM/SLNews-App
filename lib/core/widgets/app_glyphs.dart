import 'package:flutter/material.dart';

import '../domain/models/follow_models.dart';

/// Resolves the string icon keys used by seeded content into Material icons.
///
/// Content (and therefore the seed JSON) must not depend on Flutter icon
/// codepoints, so it stores stable keys and this single table maps them.
abstract final class AppGlyphs {
  static IconData category(String key) => switch (key) {
    'top' => Icons.local_fire_department_outlined,
    'politics' => Icons.account_balance_outlined,
    'business' => Icons.trending_up_outlined,
    'cars' => Icons.directions_car_outlined,
    'music' => Icons.music_note_outlined,
    'culture' => Icons.groups_outlined,
    'sports' => Icons.sports_soccer_outlined,
    'health' => Icons.health_and_safety_outlined,
    'tech' => Icons.memory_outlined,
    'education' => Icons.school_outlined,
    'mining' => Icons.terrain_outlined,
    'world' => Icons.public_outlined,
    _ => Icons.topic_outlined,
  };

  static IconData weather(String key) => switch (key) {
    'sun' => Icons.wb_sunny_outlined,
    'cloud' => Icons.cloud_outlined,
    'rain' => Icons.water_drop_outlined,
    'storm' => Icons.thunderstorm_outlined,
    'haze' => Icons.blur_on_outlined,
    _ => Icons.wb_cloudy_outlined,
  };

  static IconData follow(FollowKind kind) => switch (kind) {
    FollowKind.team => Icons.shield_outlined,
    FollowKind.league => Icons.emoji_events_outlined,
    FollowKind.location => Icons.place_outlined,
    FollowKind.publisher => Icons.newspaper_outlined,
    FollowKind.topic => Icons.tag_outlined,
  };

  static IconData notification(String key) => switch (key) {
    'breaking' => Icons.campaign_outlined,
    'team' => Icons.sports_basketball_outlined,
    'publisher' => Icons.newspaper_outlined,
    'score' => Icons.scoreboard_outlined,
    _ => Icons.notifications_none,
  };

  /// Player/team initials drawn when a crest is unavailable.
  static String initials(String label) {
    final List<String> words = label.trim().split(RegExp(r'\s+')).where((String w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final String word = words.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }
}
