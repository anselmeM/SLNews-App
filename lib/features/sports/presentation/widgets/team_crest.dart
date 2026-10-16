import 'package:flutter/material.dart';

import '../../../../core/domain/models/follow_models.dart';
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
  });

  /// Crest for a followed entity (team or league) in the Following row.
  TeamCrest.forTarget(FollowTarget target, {super.key, this.size = 48})
    : name = target.label,
      logoUrl = target.imageUrl,
      colourHex = null,
      initialsOverride = SportsViewModel.shortLabel(target);

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
    final Color background = club ?? context.colors.surfaceInverse;
    final Color foreground = club == null ? context.colors.onSurfaceInverse : Colors.white;

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
