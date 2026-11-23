import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/ad_unit.dart';
import 'package:slnews_mobile/core/domain/models/app_settings.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/domain/models/news_category.dart';
import 'package:slnews_mobile/core/domain/models/notification_item.dart';
import 'package:slnews_mobile/core/domain/models/publisher.dart';
import 'package:slnews_mobile/core/domain/models/sports_models.dart';
import 'package:slnews_mobile/core/domain/models/weather_snapshot.dart';
import 'package:slnews_mobile/core/theme/app_colors.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';

Article _article({
  String id = 'a1',
  String category = 'politics',
  String body = '<p>one two three</p>',
  bool breaking = false,
}) {
  return Article(
    id: id,
    title: 'Stelco layoffs: Ottawa weighs legal action',
    publisher: const Publisher(
      id: 'cbc',
      name: 'CBC News',
      wordmark: 'CBC NEWS',
    ),
    publishedAt: DateTime(2026, 10, 14, 17, 18),
    categoryId: category,
    bodyHtml: body,
    isBreaking: breaking,
  );
}

void main() {
  group('Article', () {
    test('round-trips through JSON without losing fields', () {
      final Article original = _article(breaking: true).copyWith(
        summary: 'Summary',
        author: 'CBC/Radio-Canada',
        imageUrl: 'https://example.com/a.jpg',
        imageCaption: 'Caption',
        imageCredit: 'Evan Mitsui/CBC',
        sourceUrl: 'https://example.com/story',
        tags: const <String>['stelco', 'ottawa'],
        isLive: true,
        readingMinutes: 4,
        previewOnly: true,
      );

      final Article restored = Article.fromJson(original.toJson());

      expect(restored, original);
      expect(restored.summary, 'Summary');
      expect(restored.tags, <String>['stelco', 'ottawa']);
      expect(restored.publisher.mark, 'CBC NEWS');
      expect(restored.isBreaking, isTrue);
      expect(restored.isLive, isTrue);
      expect(restored.previewOnly, isTrue);
    });

    test('estimates reading time from the body when the feed omits it', () {
      final String longBody =
          '<p>${List<String>.filled(660, 'word').join(' ')}</p>';
      expect(_article(body: longBody).estimatedReadingMinutes, 3);
      expect(_article(body: '<p>short</p>').estimatedReadingMinutes, 1);
      expect(_article().copyWith(readingMinutes: 9).estimatedReadingMinutes, 9);
    });

    test(
      'equality is driven by identity plus the fields the feed can change',
      () {
        expect(_article(), _article());
        expect(_article(category: 'sports'), isNot(_article()));
        expect(_article(id: 'other'), isNot(_article()));
      },
    );
  });

  group('NewsCategories', () {
    test('exposes a curated, non-empty catalogue with unique ids', () {
      expect(NewsCategories.all, isNotEmpty);
      final Set<String> ids = NewsCategories.all
          .map((NewsCategory c) => c.id)
          .toSet();
      expect(ids.length, NewsCategories.all.length);
      expect(ids, containsAll(<String>['top', 'politics', 'business']));
      // Mining remains an article topic but is no longer a newspaper tab.
      expect(ids, isNot(contains('mining')));
    });

    test('falls back to the first category for an unknown id', () {
      expect(NewsCategories.byId('does-not-exist'), NewsCategories.all.first);
      expect(NewsCategories.byId('politics').label, 'Politics');
    });
  });

  group('AppSettings', () {
    test('cycles through the text-scale steps and wraps around', () {
      const AppSettings start = AppSettings();
      expect(start.nextTextScale, 1.15);
      expect(start.copyWith(textScale: 1.5).nextTextScale, 0.9);
    });

    test('maps the persisted wire value to a Material theme mode', () {
      expect(AppThemeMode.fromWire('dark'), AppThemeMode.dark);
      expect(AppThemeMode.fromWire('nonsense'), AppThemeMode.system);
      expect(AppThemeMode.dark.materialMode, ThemeMode.dark);
    });

    test('copyWith only replaces the fields it is given', () {
      const AppSettings settings = AppSettings();
      final AppSettings updated = settings.copyWith(
        themeMode: AppThemeMode.dark,
        textScale: 1.3,
      );
      expect(updated.themeMode, AppThemeMode.dark);
      expect(updated.textScale, 1.3);
      expect(updated.breakingNewsAlertsEnabled, isTrue);
    });

    test('copyWith carries the onboarding flag through', () {
      // Regression: the shell shows onboarding until this flag flips, so
      // dropping it in copyWith made completing onboarding a no-op in memory.
      const AppSettings settings = AppSettings();
      expect(settings.onboardingCompleted, isFalse);
      expect(
        settings.copyWith(onboardingCompleted: true).onboardingCompleted,
        isTrue,
      );
      expect(
        settings
            .copyWith(onboardingCompleted: true)
            .copyWith()
            .onboardingCompleted,
        isTrue,
      );
    });

    test('equality sees every persisted preference', () {
      const AppSettings settings = AppSettings();
      expect(settings, settings.copyWith());
      // Fields the old == ignored must make a difference.
      expect(
        settings == settings.copyWith(followedTopicAlertsEnabled: false),
        isFalse,
      );
      expect(settings == settings.copyWith(onboardingCompleted: true), isFalse);
      expect(settings.hashCode == settings.copyWith().hashCode, isTrue);
    });
  });

  group('FollowingSnapshot', () {
    const FollowTarget team = FollowTarget(
      id: 'team:leone-stars',
      kind: FollowKind.team,
      label: 'Leone Stars',
    );
    const FollowTarget city = FollowTarget(
      id: 'city:bo',
      kind: FollowKind.location,
      label: 'Bo',
      subtitle: 'Southern Province',
      isPopular: true,
    );

    test('reports follow state by id', () {
      const FollowingSnapshot snapshot = FollowingSnapshot(
        followed: <FollowTarget>[team],
        suggested: <FollowTarget>[city],
      );
      expect(snapshot.isFollowed('team:leone-stars'), isTrue);
      expect(snapshot.isFollowed('city:bo'), isFalse);
      expect(snapshot.followedIds, <String>['team:leone-stars']);
    });

    test(
      'section labels group kinds the way the Following tab renders them',
      () {
        expect(FollowKind.team.sectionLabel, 'Sports');
        expect(FollowKind.league.sectionLabel, 'Sports');
        expect(FollowKind.location.sectionLabel, 'Locations');
        expect(FollowKind.topic.sectionLabel, 'Topics');
        expect(FollowKind.publisher.sectionLabel, 'Publishers');
      },
    );
  });

  group('Sports models', () {
    test('maps wire status values onto the game lifecycle', () {
      expect(GameStatus.fromWire('final'), GameStatus.finalScore);
      expect(GameStatus.fromWire('in_progress'), GameStatus.live);
      expect(GameStatus.fromWire('postponed'), GameStatus.postponed);
      expect(GameStatus.fromWire(null), GameStatus.scheduled);
      expect(GameStatus.live.wireValue, 'live');
    });

    test('renders the scoreboard status label the way the cards show it', () {
      const Team gs = Team(id: 'gs', name: 'Golden State', code: 'GS');
      const Team lal = Team(id: 'lal', name: 'Lakers', code: 'LAL');

      const GameScore finalGame = GameScore(
        id: 'g1',
        leagueLabel: 'NBA',
        away: lal,
        home: gs,
        status: GameStatus.finalScore,
        awayScore: 89,
        homeScore: 101,
      );
      expect(finalGame.statusLabel, 'FINAL');
      expect(finalGame.hasScores, isTrue);

      final GameScore upcoming = GameScore(
        id: 'g2',
        leagueLabel: 'NBA',
        away: lal,
        home: gs,
        status: GameStatus.scheduled,
        startsAt: DateTime(2026, 10, 16, 22, 30),
      );
      expect(upcoming.statusLabel, '10:30PM');
      expect(upcoming.hasScores, isFalse);
    });
  });

  group('Notification and weather models', () {
    test('notification round-trips and can be marked read', () {
      final NotificationItem item = NotificationItem(
        id: 'n1',
        title: 'Breaking',
        body: 'Stelco announces layoffs',
        receivedAt: DateTime(2026, 10, 15, 9),
        kind: NotificationKind.breaking,
        articleId: 'a1',
      );
      final NotificationItem restored = NotificationItem.fromJson(
        item.toJson(),
      );
      expect(restored.kind, NotificationKind.breaking);
      expect(restored.articleId, 'a1');
      expect(restored.isRead, isFalse);
      expect(restored.copyWith(isRead: true).isRead, isTrue);
      expect(restored.ageLabel, isNotEmpty);
    });

    test(
      'weather placeholder keeps the header stable before the first fetch',
      () {
        final WeatherSnapshot snapshot = WeatherSnapshot.placeholder(
          'Freetown',
        );
        expect(snapshot.locationLabel, 'Freetown');
        expect(snapshot.compactLabel, contains('°'));
        expect(snapshot.highC! >= snapshot.temperatureC, isTrue);
      },
    );
  });

  group('AdUnit', () {
    test('round-trips and defaults to a labelled house unit', () {
      const AdUnit unit = AdUnit(
        id: 'ad1',
        headline: 'CLAIM YOUR REWARD',
        body: 'Earn money or donate',
        ctaLabel: 'View more',
        advertiser: 'Salone Rewards',
        assetLabel: r'$20',
      );
      final AdUnit restored = AdUnit.fromJson(unit.toJson());
      expect(restored.id, 'ad1');
      expect(restored.assetLabel, r'$20');
      expect(restored.disclosure, isNull);
      expect(restored, unit);
    });
  });

  group('Design system', () {
    test('ships a coherent light and dark palette', () {
      expect(AppColors.light.brightness, Brightness.light);
      expect(AppColors.dark.brightness, Brightness.dark);
      expect(AppColors.of(Brightness.dark).canvas, AppColors.dark.canvas);
      // Cards must stay lighter than the canvas in light mode and darker in dark mode.
      expect(
        AppColors.light.surface.computeLuminance() >
            AppColors.light.canvas.computeLuminance(),
        isTrue,
      );
      expect(
        AppColors.dark.surface.computeLuminance() >
            AppColors.dark.canvas.computeLuminance(),
        isTrue,
      );
    });

    test('builds both themes with the SLNews font family', () {
      expect(AppTheme.light().textTheme.bodyLarge!.fontFamily, 'SLNewsSans');
      expect(AppTheme.dark().textTheme.bodyLarge!.fontFamily, 'SLNewsSans');
      expect(AppTheme.light().scaffoldBackgroundColor, AppColors.light.canvas);
      expect(AppTheme.dark().scaffoldBackgroundColor, AppColors.dark.canvas);
    });
  });
}
