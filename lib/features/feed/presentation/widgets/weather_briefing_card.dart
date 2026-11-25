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

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({
    required this.snapshot,
    required this.now,
    required this.briefing,
    required this.onOpenArticle,
    required this.onLocationTap,
  });

  final WeatherSnapshot snapshot;
  final DateTime now;
  final List<Article> briefing;
  final ValueChanged<Article> onOpenArticle;
  final VoidCallback onLocationTap;

  static const Color _ink = Color(0xFF0B1730);
  static const Color _mutedInk = Color(0xA60F1B35);

  @override
  Widget build(BuildContext context) {
    final String daypart = _daypart(now);
    final String adjective = _weatherAdjective(snapshot.glyph);
    final String greeting = _weatherGreeting(adjective, daypart, snapshot);
    final String headline = !snapshot.isAvailable
        ? (snapshot.isLoading ? 'Checking weather' : 'Weather unavailable')
        : '$adjective $daypart';

    return ClipRRect(
      borderRadius: AppRadius.cardRadius,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFEAF2FF),
              Color(0xFFCCE0FF),
              Color(0xFFA9C8FF),
              Color(0xFF7FA7F4),
            ],
            stops: <double>[0, 0.36, 0.7, 1],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              right: -64,
              top: -78,
              child: _Glow(
                size: 238,
                color: Colors.white.withValues(alpha: 0.32),
              ),
            ),
            Positioned(
              left: -72,
              bottom: -112,
              child: _Glow(
                size: 190,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _CardTop(
                    eyebrow: 'DAILY BRIEFING · ${daypart.toUpperCase()}',
                    date: _shortDate(now),
                    mutedInk: _mutedInk,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    header: true,
                    child: Text(
                      headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.screenTitle.copyWith(
                        color: _ink,
                        fontSize: 38,
                        height: 0.98,
                        letterSpacing: -1.6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    greeting,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.meta.copyWith(
                      color: _mutedInk,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _WeatherMetrics(
                    snapshot: snapshot,
                    ink: _ink,
                    mutedInk: _mutedInk,
                    onLocationTap: onLocationTap,
                  ),
                  if (briefing.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    Divider(height: 1, color: _ink.withValues(alpha: 0.15)),
                    const SizedBox(height: AppSpacing.md),
                    _BriefingHeader(
                      count: briefing.length,
                      ink: _ink,
                      mutedInk: _mutedInk,
                    ),
                    for (
                      int index = 0;
                      index < briefing.length;
                      index++
                    ) ...<Widget>[
                      if (index > 0)
                        Divider(height: 1, color: _ink.withValues(alpha: 0.12)),
                      _BriefingRow(
                        index: index,
                        article: briefing[index],
                        ink: _ink,
                        onTap: () => onOpenArticle(briefing[index]),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BriefingOnlyCard extends StatelessWidget {
  const _BriefingOnlyCard({
    required this.briefing,
    required this.onOpenArticle,
  });

  final List<Article> briefing;
  final ValueChanged<Article> onOpenArticle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'DAILY BRIEFING',
                    style: context.typography.overline.copyWith(
                      color: context.colors.onSurfaceVariant,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${briefing.length} '
                  '${briefing.length == 1 ? 'story' : 'stories'}',
                  style: context.typography.caption.copyWith(
                    color: context.colors.onSurfaceFaint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (int i = 0; i < briefing.length; i++) ...<Widget>[
              if (i > 0) Divider(height: 1, color: context.colors.divider),
              _BriefingRow(
                index: i,
                article: briefing[i],
                ink: context.colors.onSurface,
                onTap: () => onOpenArticle(briefing[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardTop extends StatelessWidget {
  const _CardTop({
    required this.eyebrow,
    required this.date,
    required this.mutedInk,
  });

  final String eyebrow;
  final String date;
  final Color mutedInk;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            eyebrow,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typography.overline.copyWith(
              color: mutedInk,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          date,
          style: context.typography.overline.copyWith(
            color: mutedInk,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _WeatherMetrics extends StatelessWidget {
  const _WeatherMetrics({
    required this.snapshot,
    required this.ink,
    required this.mutedInk,
    required this.onLocationTap,
  });

  final WeatherSnapshot snapshot;
  final Color ink;
  final Color mutedInk;
  final VoidCallback onLocationTap;

  @override
  Widget build(BuildContext context) {
    if (!snapshot.isAvailable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                snapshot.isLoading
                    ? Icons.schedule_outlined
                    : Icons.cloud_off_outlined,
                size: 22,
                color: mutedInk,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  snapshot.conditionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.cardTitle.copyWith(
                    color: ink,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _tappableLocation(context),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              '${snapshot.temperatureC}°',
              style: context.typography.screenTitle.copyWith(
                color: ink,
                fontSize: 54,
                height: 0.86,
                letterSpacing: -3,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          AppGlyphs.weather(snapshot.glyph),
                          size: 14,
                          color: ink,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            snapshot.conditionLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.typography.cardTitle.copyWith(
                              color: ink,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    _tappableLocation(context),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (snapshot.highC != null ||
            snapshot.lowC != null ||
            snapshot.humidityPercent != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              if (snapshot.highC != null)
                _MetricChip(label: 'H ${snapshot.highC}°', ink: ink),
              if (snapshot.lowC != null)
                _MetricChip(label: 'L ${snapshot.lowC}°', ink: ink),
              if (snapshot.humidityPercent != null)
                _MetricChip(label: '${snapshot.humidityPercent}%', ink: ink),
            ],
          ),
        ],
      ],
    );
  }

  Widget _tappableLocation(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Change weather location',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onLocationTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.place_outlined, size: 12, color: mutedInk),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                snapshot.locationLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.caption.copyWith(
                  color: mutedInk,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                  decoration: TextDecoration.underline,
                  decorationColor: mutedInk,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more, size: 13, color: mutedInk),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.ink});

  final String label;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 27,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.43),
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
      ),
      child: Text(
        label,
        style: context.typography.caption.copyWith(
          color: ink,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

class _BriefingHeader extends StatelessWidget {
  const _BriefingHeader({
    required this.count,
    required this.ink,
    required this.mutedInk,
  });

  final int count;
  final Color ink;
  final Color mutedInk;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'TODAY’S BRIEFING',
            style: context.typography.overline.copyWith(
              color: mutedInk,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          '$count ${count == 1 ? 'story' : 'stories'}',
          style: context.typography.caption.copyWith(
            color: mutedInk,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BriefingRow extends StatelessWidget {
  const _BriefingRow({
    required this.index,
    required this.article,
    required this.ink,
    required this.onTap,
  });

  final int index;
  final Article article;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableInkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 22,
              child: Text(
                '${index + 1}'.padLeft(2, '0'),
                style: context.typography.overline.copyWith(
                  color: const Color(0xFF2952A3),
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                article.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.typography.cardTitleSmall.copyWith(
                  color: ink,
                  fontSize: 13,
                  height: 1.34,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.chevron_right,
                size: 15,
                color: ink.withValues(alpha: 0.43),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

String _daypart(DateTime now) {
  if (now.hour < 12) return 'morning';
  if (now.hour < 17) return 'afternoon';
  return 'evening';
}

String _weatherAdjective(String glyph) {
  return switch (glyph) {
    'sun' => 'Sunny',
    'rain' => 'Rainy',
    'storm' => 'Stormy',
    'snow' => 'Snowy',
    'cloud' => 'Cloudy',
    _ => 'Cloudy',
  };
}

String _weatherGreeting(
  String adjective,
  String daypart,
  WeatherSnapshot snapshot,
) {
  if (snapshot.isLoading) {
    return 'Loading the forecast for ${snapshot.locationLabel}.';
  }
  if (!snapshot.isAvailable) {
    return 'Weather for ${snapshot.locationLabel} isn’t available right now.';
  }
  return 'A ${adjective.toLowerCase()} $daypart in ${snapshot.locationLabel} — '
      'here’s what matters today.';
}

String _shortDate(DateTime now) {
  const List<String> weekdays = <String>[
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];
  const List<String> months = <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${weekdays[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
}
