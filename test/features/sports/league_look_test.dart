import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/features/sports/presentation/widgets/league_look.dart';

void main() {
  test('every recognised league gets its own icon', () {
    const Map<String, IconData> expected = <String, IconData>{
      'NBA': Icons.sports_basketball,
      'NFL': Icons.sports_football,
      'MLB': Icons.sports_baseball,
      'NHL': Icons.sports_hockey,
      'Sierra Leone Premier League': Icons.sports_soccer,
      'European Leagues': Icons.sports_soccer,
      'Champions League': Icons.sports_soccer,
      'La Liga': Icons.sports_soccer,
      'Serie A': Icons.sports_soccer,
      'Bundesliga': Icons.sports_soccer,
      'Ligue 1': Icons.sports_soccer,
      'AFCON': Icons.sports_soccer,
      'Formula 1': Icons.sports_motorsports,
      'Tennis': Icons.sports_tennis,
      'Cricket': Icons.sports_cricket,
      'Golf': Icons.golf_course,
      'Premier League': Icons.sports_soccer,
    };
    for (final MapEntry<String, IconData> entry in expected.entries) {
      expect(
        LeagueLook.forLabel(entry.key).icon,
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('matching is case-insensitive and falls back to football green', () {
    final LeagueLook lower = LeagueLook.forLabel('nba');
    final LeagueLook fallback = LeagueLook.forLabel('Unknown competition');

    expect(lower.icon, Icons.sports_basketball);
    expect(lower.top, isNot(fallback.top));
    expect(fallback.icon, Icons.sports_soccer);
    expect(fallback.top, const Color(0xFF062E1C));
  });
}
