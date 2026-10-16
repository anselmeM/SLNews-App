import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/models/follow_models.dart';
import '../../../../core/domain/models/weather_snapshot.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_glyphs.dart';
import 'location_picker_sheet.dart';

/// Compact "weather + alert" row that opens the For You header.
///
/// The chip is sized from the token scale, never from the network, so a slow or
/// failed [activeWeatherProvider] cannot shift the page: both the loading and
/// the error case fall back to [WeatherSnapshot.placeholder] for the active
/// location. Tapping it opens the location picker.
class WeatherAlertHeader extends ConsumerWidget {
  const WeatherAlertHeader({
    super.key,
    required this.location,
    this.hasBreaking = false,
  });

  /// Active location, resolved by the view model so the label is stable even
  /// while the weather request is in flight.
  final NewsLocation location;

  /// Draws the red `BREAKING` tag when any story in the feed is breaking.
  final bool hasBreaking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WeatherSnapshot> weather = ref.watch(
      activeWeatherProvider,
    );
    final WeatherSnapshot snapshot =
        weather.value ?? WeatherSnapshot.placeholder(location.label);

    return Semantics(
      button: true,
      label: 'Weather for ${snapshot.locationLabel}. Change location.',
      child: InkWell(
        onTap: () => openLocationPicker(context, ref),
        borderRadius: AppRadius.pillRadius,
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
                  '${snapshot.temperatureC}° ${snapshot.locationLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.meta.copyWith(
                    color: context.colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (hasBreaking) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                const _BreakingTag(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Red `BREAKING` overline tag mirroring the hero card's label.
class _BreakingTag extends StatelessWidget {
  const _BreakingTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: context.colors.live,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        'BREAKING',
        style: context.typography.overline.copyWith(color: Colors.white),
      ),
    );
  }
}
