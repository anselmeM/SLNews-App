import 'package:flutter/material.dart';

/// League-specific icon and header gradient used by the Sports blocks.
class LeagueLook {
  const LeagueLook(this.icon, this.top, this.bottom);

  final IconData icon;
  final Color top;
  final Color bottom;

  static LeagueLook forLabel(String label) {
    final String value = label.toUpperCase();
    if (value.contains('NBA')) {
      return const LeagueLook(
        Icons.sports_basketball,
        Color(0xFF0B2E6B),
        Color(0xFF1558B0),
      );
    }
    if (value.contains('NFL')) {
      return const LeagueLook(
        Icons.sports_football,
        Color(0xFF0A2A22),
        Color(0xFF146B4A),
      );
    }
    if (value.contains('MLB')) {
      return const LeagueLook(
        Icons.sports_baseball,
        Color(0xFF1C2340),
        Color(0xFF31508E),
      );
    }
    if (value.contains('NHL')) {
      return const LeagueLook(
        Icons.sports_hockey,
        Color(0xFF1A1A1E),
        Color(0xFF3A3A42),
      );
    }
    if (value.contains('SIERRA LEONE PREMIER')) {
      return const LeagueLook(
        Icons.sports_soccer,
        Color(0xFF062E1C),
        Color(0xFF0F7A43),
      );
    }
    if (value.contains('EUROPEAN')) {
      return const LeagueLook(
        Icons.sports_soccer,
        Color(0xFF15102E),
        Color(0xFF3B2A7A),
      );
    }
    if (value.contains('CHAMPIONS LEAGUE')) {
      return const LeagueLook(
        Icons.sports_soccer,
        Color(0xFF081A4B),
        Color(0xFF1746A2),
      );
    }
    if (value.contains('LA LIGA')) {
      return const LeagueLook(
        Icons.sports_soccer,
        Color(0xFF4A1010),
        Color(0xFFB52A2A),
      );
    }
    if (value.contains('SERIE A')) {
      return const LeagueLook(
        Icons.sports_soccer,
        Color(0xFF102A5E),
        Color(0xFF1D5AA6),
      );
    }
    if (value.contains('BUNDESLIGA')) {
      return const LeagueLook(
        Icons.sports_soccer,
        Color(0xFF4A0A0A),
        Color(0xFFC21B1B),
      );
    }
    if (value.contains('LIGUE 1')) {
      return const LeagueLook(
        Icons.sports_soccer,
        Color(0xFF0A2A4A),
        Color(0xFF1266A8),
      );
    }
    if (value.contains('AFCON')) {
      return const LeagueLook(
        Icons.sports_soccer,
        Color(0xFF4A3200),
        Color(0xFFB3801A),
      );
    }
    if (value.contains('FORMULA')) {
      return const LeagueLook(
        Icons.sports_motorsports,
        Color(0xFF3A0A0A),
        Color(0xFFB01818),
      );
    }
    if (value.contains('TENNIS')) {
      return const LeagueLook(
        Icons.sports_tennis,
        Color(0xFF2A3A0A),
        Color(0xFF6B8A1A),
      );
    }
    if (value.contains('CRICKET')) {
      return const LeagueLook(
        Icons.sports_cricket,
        Color(0xFF0A3A2A),
        Color(0xFF117A5A),
      );
    }
    if (value.contains('GOLF')) {
      return const LeagueLook(
        Icons.golf_course,
        Color(0xFF0A3A0A),
        Color(0xFF1F7A1F),
      );
    }
    if (value.contains('PREMIER')) {
      return const LeagueLook(
        Icons.sports_soccer,
        Color(0xFF2B0A45),
        Color(0xFF5B1E8A),
      );
    }
    return const LeagueLook(
      Icons.sports_soccer,
      Color(0xFF062E1C),
      Color(0xFF0F5A37),
    );
  }
}
