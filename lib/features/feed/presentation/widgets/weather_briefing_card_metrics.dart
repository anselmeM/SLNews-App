part of 'weather_briefing_card.dart';

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
