import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/domain/models/follow_models.dart';
import '../../../../core/domain/models/weather_location_state.dart';
import '../../../../core/domain/models/weather_snapshot.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/time_ago.dart';
import '../../../../core/widgets/app_glyphs.dart';
import '../../../../core/widgets/pressable_ink_well.dart';
import 'weather_location_sheet.dart';

part 'weather_briefing_card_metrics.dart';
part 'weather_briefing_card_sections.dart';

/// Merged weather + daily-briefing card at the top of For You.
///
/// Weather and editorial briefing share one surface so the header reads as a
/// single daily destination instead of a chip plus a separate card. There is
/// intentionally no hourly strip: the card stays compact and only shows data
/// the app actually has.
class WeatherBriefingCard extends ConsumerWidget {
  const WeatherBriefingCard({
    super.key,
    required this.showWeather,
    required this.briefing,
    required this.onOpenArticle,
  });

  final bool showWeather;
  final List<Article> briefing;
  final ValueChanged<Article> onOpenArticle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!showWeather && briefing.isEmpty) return const SizedBox.shrink();

    if (!showWeather) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          0,
        ),
        child: _BriefingOnlyCard(
          briefing: briefing,
          onOpenArticle: onOpenArticle,
        ),
      );
    }

    final WeatherLocationState locationState = ref.watch(
      weatherLocationControllerProvider,
    );
    final AsyncValue<WeatherSnapshot> weather = ref.watch(
      activeWeatherProvider,
    );
    final NewsLocation selected = locationState.location;
    final WeatherSnapshot? value = weather.value;
    // AsyncValue can retain the previous place's snapshot while the new
    // location loads. Only trust a value whose id/label matches the selection.
    final WeatherSnapshot snapshot;
    if (weather.hasError) {
      // A failed same-place refresh must not present the previous forecast as
      // if it were current.
      snapshot = WeatherSnapshot.unavailable(
        selected.label,
        locationId: selected.id,
      );
    } else if (value != null && value.matches(selected)) {
      snapshot = value;
    } else if (weather.isLoading) {
      snapshot = WeatherSnapshot.loading(
        selected.label,
        locationId: selected.id,
      );
    } else {
      snapshot = WeatherSnapshot.unavailable(
        selected.label,
        locationId: selected.id,
      );
    }
    final DateTime now = appNow();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: _WeatherCard(
        snapshot: snapshot,
        now: now,
        briefing: briefing,
        onOpenArticle: onOpenArticle,
        onLocationTap: () => showWeatherLocationSheet(context),
      ),
    );
  }
}
