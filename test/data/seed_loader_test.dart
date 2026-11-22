import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/seed/seed_data.dart';
import 'package:slnews_mobile/core/data/seed/seed_loader.dart';
import 'package:slnews_mobile/core/domain/models/ad_unit.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/domain/models/news_category.dart';
import 'package:slnews_mobile/core/domain/models/notification_item.dart';
import 'package:slnews_mobile/core/domain/models/sports_models.dart';

/// An [AssetBundle] that fails every read, standing in for a broken build.
class _MissingAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('asset not bundled: $key');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Declared first on purpose: the loader caches only successful, non-empty
  // reads, so a failed read here cannot leak into the assertions below.
  test(
    'returns an empty bundle instead of throwing when assets are missing',
    () async {
      final SeedData data = await AssetSeedLoader(bundle: _MissingAssetBundle())
          .load();

      expect(data.articles, isEmpty);
      expect(data.followables, isEmpty);
      expect(data.ads, isEmpty);
      expect(data.notifications, isEmpty);
      expect(data.scoreboard.games, isEmpty);
      expect(data.hasNoArticles, isTrue);
      expect(
        data.locations,
        isNotEmpty,
        reason: 'places come from the frozen domain constant',
      );
    },
  );

  test('parses every bundled asset', () async {
    final SeedData data = await const AssetSeedLoader().load();

    expect(data.articles.length, inInclusiveRange(20, 30));
    expect(
      data.articles.map((Article a) => a.id).toSet(),
      hasLength(data.articles.length),
    );
    expect(data.scoreboard.games, isNotEmpty);
    expect(data.scoreboard.providerLabel, 'yahoo/sports');
    expect(data.followables, isNotEmpty);
    expect(data.locations, hasLength(5));
    expect(data.notifications, isNotEmpty);
    expect(data.ads, hasLength(3));
    expect(data.weather, hasLength(5));
    expect(data.standings, isNotEmpty);
    expect(data.hasNoArticles, isFalse);
  });

  test('converts publishedMinutesAgo into a recent timestamp', () async {
    final SeedData data = await const AssetSeedLoader().load();
    final DateTime now = DateTime.now();

    for (final Article article in data.articles) {
      expect(
        article.publishedAt.isAfter(now.subtract(const Duration(days: 3))),
        isTrue,
      );
      expect(
        article.publishedAt.isBefore(now.add(const Duration(minutes: 1))),
        isTrue,
      );
    }
  });

  test(
    'seed articles are renderable: body, hero image and publisher',
    () async {
      final SeedData data = await const AssetSeedLoader().load();

      int breaking = 0;
      int live = 0;
      int quoted = 0;
      for (final Article article in data.articles) {
        expect(article.title, isNotEmpty);
        expect(article.summary, isNotEmpty);
        expect(RegExp(r'<h2>').allMatches(article.bodyHtml), hasLength(1));
        expect(
          RegExp(r'<p>').allMatches(article.bodyHtml).length,
          inInclusiveRange(4, 9),
        );
        expect(article.imageUrl, startsWith('https://picsum.photos/seed/'));
        expect(article.imageCaption, isNotNull);
        expect(article.imageCredit, isNotNull);
        expect(article.author, isNotNull);
        expect(article.publisher.name, isNotEmpty);
        expect(article.publisher.id, isNotEmpty);
        expect(article.readingMinutes, greaterThan(0));
        expect(article.sourceUrl, isNotNull);
        if (article.isBreaking) breaking++;
        if (article.isLive) live++;
        if (article.bodyHtml.contains('<blockquote>')) quoted++;
      }

      expect(breaking, 3);
      expect(live, 1);
      expect(quoted, greaterThanOrEqualTo(2));
    },
  );

  test('every category pill has seeded content', () async {
    final SeedData data = await const AssetSeedLoader().load();

    for (final NewsCategory category in NewsCategories.all) {
      if (category.id == 'top') continue;
      expect(
        data.articles.where((Article a) => a.categoryId == category.id),
        isNotEmpty,
        reason: 'no seed article for ${category.id}',
      );
    }
  });

  test(
    'notifications deep-link to seeded articles and weather covers every city',
    () async {
      final SeedData data = await const AssetSeedLoader().load();
      final Set<String> ids = data.articles.map((Article a) => a.id).toSet();

      for (final NotificationItem item in data.notifications) {
        expect(item.title, isNotEmpty);
        expect(item.body, isNotEmpty);
        final String? articleId = item.articleId;
        if (articleId != null) expect(ids, contains(articleId));
      }
      for (final NewsLocation location in data.locations) {
        expect(
          data.weather[location.id],
          isNotNull,
          reason: 'missing weather for ${location.id}',
        );
      }
    },
  );

  test(
    'followables cover every kind and mark the popular suggestions',
    () async {
      final SeedData data = await const AssetSeedLoader().load();

      for (final FollowKind kind in FollowKind.values) {
        expect(
          data.followables.where((FollowTarget t) => t.kind == kind),
          isNotEmpty,
          reason: 'no $kind targets in the catalogue',
        );
      }
      expect(
        data.followables.where(
          (FollowTarget t) => t.isPopular && t.kind == FollowKind.location,
        ),
        hasLength(2),
      );
      expect(
        data.followables.where(
          (FollowTarget t) => t.isPopular && t.kind == FollowKind.topic,
        ),
        hasLength(2),
      );
    },
  );

  test('the house ad carries its offer label and disclosure', () async {
    final SeedData data = await const AssetSeedLoader().load();
    final AdUnit rewards = data.ads.firstWhere(
      (AdUnit ad) => ad.id == 'ad-salone-rewards',
    );

    expect(rewards.headline, 'CLAIM YOUR REWARD');
    expect(rewards.assetLabel, r'$20');
    expect(rewards.ctaLabel, 'View more');
    expect(rewards.disclosure, contains('JustPlay'));
  });

  test('standings belong to the seeded league', () async {
    final SeedData data = await const AssetSeedLoader().load();

    expect(data.standings, hasLength(6));
    for (final TeamStanding row in data.standings) {
      expect(row.leagueId, 'league:spl');
      expect(row.record, isNotEmpty);
      expect(row.team.code, hasLength(3));
      expect(row.rank, greaterThan(0));
    }
  });
}
