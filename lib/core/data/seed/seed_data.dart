import '../../domain/models/ad_unit.dart';
import '../../domain/models/article.dart';
import '../../domain/models/follow_models.dart';
import '../../domain/models/notification_item.dart';
import '../../domain/models/sports_models.dart';
import '../../domain/models/weather_snapshot.dart';

/// Everything SLNews ships offline: editorial content, sports, followables,
/// places, alerts, ad units and weather, in one immutable bundle.
///
/// The data layer resolves every read against this bundle last, which is what
/// guarantees the app has content on a fresh install with no connectivity.
class SeedData {
  /// Creates a seed bundle; every collection defaults to being required so a
  /// missing asset is visible at construction rather than at render time.
  const SeedData({
    required this.articles,
    required this.scoreboard,
    required this.followables,
    required this.locations,
    required this.notifications,
    required this.ads,
    required this.weather,
    required this.standings,
  });

  /// Empty-but-valid bundle returned when no asset could be read.
  ///
  /// Deliberately `final` rather than `const`: [ScoreboardSnapshot] requires a
  /// non-const `DateTime`, which no const expression can build.
  static final SeedData empty = SeedData(
    articles: const <Article>[],
    scoreboard: ScoreboardSnapshot(
      games: const <GameScore>[],
      providerLabel: 'slnews',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    ),
    followables: const <FollowTarget>[],
    locations: SlLocations.all,
    notifications: const <NotificationItem>[],
    ads: const <AdUnit>[],
    weather: const <String, WeatherSnapshot>{},
    standings: const <TeamStanding>[],
  );

  final List<Article> articles;
  final ScoreboardSnapshot scoreboard;
  final List<FollowTarget> followables;
  final List<NewsLocation> locations;
  final List<NotificationItem> notifications;
  final List<AdUnit> ads;

  /// Conditions keyed by location id (`city:freetown`).
  final Map<String, WeatherSnapshot> weather;

  final List<TeamStanding> standings;

  /// True when the bundle carries no editorial content at all.
  bool get hasNoArticles => articles.isEmpty;
}
