import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/models/follow_models.dart';
import '../../../../core/domain/models/weather_snapshot.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_glyphs.dart';

/// Compact weather row that opens the For You header.
///
/// The chip is sized from the token scale, never from the network, so a slow or
/// failed [activeWeatherProvider] cannot shift the page: both the loading and
/// the error case fall back to [WeatherSnapshot.placeholder] for the active
/// location. It is read-only: the feed covers Sierra Leone as a whole, so there
/// is no city to switch. Breaking news lives in its own dismissible row, so this
/// widget never carries a permanent alert tag.
class WeatherAlertHeader extends ConsumerWidget {
  const WeatherAlertHeader({
    super.key,
    required this.location,
    this.showWeather = true,
  });

  /// Active location, resolved by the view model so the label is stable even
  /// while the weather request is in flight.
  final NewsLocation location;

  /// Reader preference: "Show weather forecast". When false the whole row is
  /// hidden; breaking alerts live in their own dismissible row.
  final bool showWeather;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!showWeather) return const SizedBox.shrink();

    final AsyncValue<WeatherSnapshot> weather = ref.watch(
      activeWeatherProvider,
    );
    final WeatherSnapshot snapshot =
        weather.value ?? WeatherSnapshot.placeholder(location.label);

    return Semantics(
      label: 'Weather for ${snapshot.locationLabel}',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              AppGlyphs.weather(snapshot.glyph),
              size: 18,
              color: context.colors.onSurface,
            ),
            const SizedBox(width: AppSpacing.xs),
            // Flexible + ellipsis keeps the chip inside a 320pt screen and at
            // large text scales instead of overflowing the header row.
            Flexible(
              child: Text(
                snapshot.compactLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.meta.copyWith(
                  color: context.colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
