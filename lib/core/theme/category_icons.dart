import 'package:flutter/material.dart';

/// Material glyph for a category, used by the editorial image fallback.
IconData articleCategoryIcon(String? categoryId) {
  final String id = (categoryId ?? '').toLowerCase();
  if (id.contains('sport') || id.contains('football')) {
    return Icons.sports_soccer;
  }
  if (id.contains('politic') || id.contains('government')) {
    return Icons.account_balance_outlined;
  }
  if (id.contains('business') ||
      id.contains('economy') ||
      id.contains('market')) {
    return Icons.trending_up;
  }
  if (id.contains('health') || id.contains('medical')) {
    return Icons.health_and_safety_outlined;
  }
  if (id.contains('culture') ||
      id.contains('music') ||
      id.contains('entertain')) {
    return Icons.music_note_outlined;
  }
  if (id.contains('tech') || id.contains('science')) {
    return Icons.memory_outlined;
  }
  if (id.contains('mining') || id.contains('diamond')) {
    return Icons.diamond_outlined;
  }
  if (id.contains('weather') || id.contains('climate')) {
    return Icons.wb_sunny_outlined;
  }
  if (id.contains('world') ||
      id.contains('international') ||
      id.contains('africa')) {
    return Icons.public;
  }
  return Icons.newspaper;
}
