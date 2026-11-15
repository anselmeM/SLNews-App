import 'package:flutter/material.dart';

import '../../../../core/domain/models/follow_models.dart';
import '../../../../core/domain/models/sports_models.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_glyphs.dart';
import '../../../../core/widgets/sl_network_image.dart';
import '../viewmodels/sports_view_model.dart';

/// Circular team crest used by the scoreboard strip and the Following row.
///
/// A remote crest is always drawn through `SlNetworkImage` at a fixed square
/// size (clipped to a circle) so the strip never reflows while the logo loads.
/// When a team has no logo the crest degrades to a filled circle in the club
/// colour carrying the initials, which is the fallback the reference UI uses.
class TeamCrest extends StatelessWidget {
  /// Crest for a [Team] from the scoreboard.
  const TeamCrest({
    super.key,
    required this.name,
    this.logoUrl,
    this.colourHex,
    this.size = 28,
    this.initialsOverride,
    this.monochrome = false,
  });

  /// Crest for a followed entity (team or league) in the Following row.
  TeamCrest.forTarget(
    FollowTarget target, {
    super.key,
    this.size = 48,
    this.monochrome = false,
  }) : name = target.label,
       logoUrl = target.imageUrl ?? _knownLogos[target.id],
       colourHex = null,
       initialsOverride = SportsViewModel.shortLabel(target);

  /// Broadcast-crest URLs for catalogue teams whose seed has no image.
  static const Map<String, String> _knownLogos = <String, String>{
    'team:lal': 'https://a.espncdn.com/i/teamlogos/nba/500/lal.png',
  };

  /// ESPN crest for common NBA clubs, keyed by the three-letter code.
  static String? knownTeamLogo(Team team) {
    if (team.logoUrl != null && team.logoUrl!.isNotEmpty) return team.logoUrl;
    const Map<String, String> nba = <String, String>{
      'ATL': 'atl',
      'BOS': 'bos',
      'BKN': 'bkn',
      'CHA': 'cha',
      'CHI': 'chi',
      'CLE': 'cle',
      'DAL': 'dal',
      'DEN': 'den',
      'DET': 'det',
      'GSW': 'gs',
      'HOU': 'hou',
      'IND': 'ind',
      'LAC': 'lac',
      'LAL': 'lal',
      'MEM': 'mem',
      'MIA': 'mia',
      'MIL': 'mil',
      'MIN': 'min',
      'NOP': 'no',
      'NYK': 'ny',
      'OKC': 'okc',
      'ORL': 'orl',
      'PHI': 'phi',
      'PHO': 'phx',
      'POR': 'por',
      'SAC': 'sac',
      'SAS': 'sa',
      'TOR': 'tor',
      'UTA': 'utah',
      'WAS': 'wsh',
      'WSH': 'wsh',
    };
    final String? slug = nba[team.code.toUpperCase()];
    return slug == null
        ? null
        : 'https://a.espncdn.com/i/teamlogos/nba/500/$slug.png';
  }

  /// Team or league name; supplies the initials when no crest is available.
  final String name;

  /// Remote crest; when absent the coloured circle is drawn instead.
  final String? logoUrl;

  /// `#RRGGBB` club colour parsed by [parseTeamColour].
  final String? colourHex;

  /// Diameter in logical pixels.
  final double size;

  /// Explicit fallback text; defaults to [AppGlyphs.initials] of [name].
  final String? initialsOverride;

  /// Neutral fallback disc for dense surfaces such as score cards.
  ///
  /// Club colours are still used for the Following row, but saturated green/red
  /// fallbacks read as chips beside the neutral editorial cards.
  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    final String? url = logoUrl;
    if (url != null && url.trim().isNotEmpty) {
      return SlNetworkImage(
        url: url,
        width: size,
        height: size,
        borderRadius: BorderRadius.all(Radius.circular(size / 2)),
      );
    }

    final String? explicit = initialsOverride?.trim();
    final String label = explicit != null && explicit.isNotEmpty
        ? explicit
        : AppGlyphs.initials(name);

    // A followed target carries no club colour, so the fallback must still be a
    // dark disc: white initials on `surfaceMuted` are unreadable.
    final Color? club = parseTeamColour(colourHex);
    final Color background = monochrome
        ? context.colors.surfaceMuted
        : (club ?? context.colors.surfaceInverse);
    final Color foreground = monochrome
        ? context.colors.onSurfaceVariant
        : (club == null ? context.colors.onSurfaceInverse : Colors.white);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.14),
          child: Text(
            label,
            maxLines: 1,
            style: context.typography.overline.copyWith(
              color: foreground,
              fontSize: size >= 40 ? 15 : 11,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Parses a `#RRGGBB` / `RRGGBB` club colour into an opaque [Color].
///
/// Returns `null` for anything malformed so the caller can fall back to a theme
/// token instead of guessing. This is the one place in the Sports feature where
/// a raw colour value is constructed from content.
Color? parseTeamColour(String? hex) {
  if (hex == null) return null;
  final String cleaned = hex.trim().replaceFirst('#', '');
  if (cleaned.length != 6) return null;
  final int? value = int.tryParse(cleaned, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}
