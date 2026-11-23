import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/data/repositories/default_user_state_repository.dart';

void main() {
  group('DefaultUserStateRepository defaults', () {
    test('reads safe defaults before anything is written', () {
      final DefaultUserStateRepository repository = DefaultUserStateRepository(
        preferences: InMemoryPreferencesStore(),
      );

      expect(repository.bookmarkedIds, isEmpty);
      expect(repository.likedIds, isEmpty);
      expect(repository.themeMode, 'system');
      expect(repository.textScale, 1.0);
      expect(repository.activeLocationId, 'city:freetown');
      expect(repository.breakingNewsAlertsEnabled, isTrue);
    });
  });

  group('DefaultUserStateRepository writes', () {
    late InMemoryPreferencesStore preferences;
    late DefaultUserStateRepository repository;

    setUp(() {
      preferences = InMemoryPreferencesStore();
      repository = DefaultUserStateRepository(preferences: preferences);
    });

    test('toggles bookmarks on and off', () async {
      await repository.toggleBookmark('art-1');
      expect(repository.isBookmarked('art-1'), isTrue);
      expect(repository.bookmarkedIds, <String>{'art-1'});

      await repository.toggleBookmark('art-2');
      expect(repository.bookmarkedIds, <String>{'art-1', 'art-2'});

      await repository.toggleBookmark('art-1');
      expect(repository.isBookmarked('art-1'), isFalse);
      expect(repository.bookmarkedIds, <String>{'art-2'});
    });

    test('keeps reader state separate per account and anonymous', () async {
      String account = 'user-a';
      final DefaultUserStateRepository scoped = DefaultUserStateRepository(
        preferences: preferences,
        accountId: () => account,
      );

      await scoped.toggleBookmark('a-story');
      await scoped.toggleLike('a-liked');
      expect(scoped.bookmarkedIds, <String>{'a-story'});
      expect(scoped.likedIds, <String>{'a-liked'});

      account = 'user-b';
      expect(scoped.bookmarkedIds, isEmpty);
      expect(scoped.likedIds, isEmpty);
      await scoped.toggleBookmark('b-story');

      account = 'user-a';
      expect(scoped.bookmarkedIds, <String>{'a-story'});
      expect(scoped.isBookmarked('b-story'), isFalse);

      account = 'anonymous';
      expect(scoped.bookmarkedIds, isEmpty);
      expect(scoped.likedIds, isEmpty);
    });

    test('adopts anonymous saves once when the reader signs in', () async {
      String account = 'anonymous';
      final DefaultUserStateRepository scoped = DefaultUserStateRepository(
        preferences: preferences,
        accountId: () => account,
      );
      await scoped.toggleBookmark('saved-while-signed-out');

      account = 'user-a';
      expect(scoped.bookmarkedIds, <String>{'saved-while-signed-out'});

      // The anonymous namespace was cleared by the adoption, so signing out
      // cannot expose those rows to the next person on the device.
      account = 'anonymous';
      expect(scoped.bookmarkedIds, isEmpty);
    });

    test('keeps likes separate from bookmarks', () async {
      await repository.toggleLike('art-1');
      expect(repository.isLiked('art-1'), isTrue);
      expect(repository.isBookmarked('art-1'), isFalse);
      expect(preferences.stringSet('user.likes.anonymous'), <String>{'art-1'});
      expect(preferences.stringSet('user.bookmarks.anonymous'), isEmpty);

      await repository.toggleLike('art-1');
      expect(repository.isLiked('art-1'), isFalse);
    });

    test('persists settings setters', () async {
      await repository.setThemeMode('dark');
      await repository.setTextScale(1.25);
      await repository.setActiveLocationId('city:bo');
      await repository.setBreakingNewsAlertsEnabled(false);
      await repository.toggleBookmark('art-9');

      expect(repository.themeMode, 'dark');
      expect(repository.textScale, 1.25);
      expect(repository.activeLocationId, 'city:bo');
      expect(repository.breakingNewsAlertsEnabled, isFalse);

      // A fresh repository over the same store sees exactly the same state.
      final DefaultUserStateRepository reopened = DefaultUserStateRepository(
        preferences: preferences,
      );
      expect(reopened.themeMode, 'dark');
      expect(reopened.textScale, 1.25);
      expect(reopened.activeLocationId, 'city:bo');
      expect(reopened.breakingNewsAlertsEnabled, isFalse);
      expect(reopened.isBookmarked('art-9'), isTrue);
    });

    test('ignores values of the wrong type instead of throwing', () {
      final DefaultUserStateRepository repository = DefaultUserStateRepository(
        preferences: InMemoryPreferencesStore(<String, Object?>{
          'settings.themeMode': 42,
          'settings.textScale': 'large',
          'settings.breakingAlerts': 'yes',
          'user.bookmarks': <String>['art-1'],
        }),
      );

      expect(repository.themeMode, 'system');
      expect(repository.textScale, 1.0);
      expect(repository.breakingNewsAlertsEnabled, isTrue);
      expect(repository.bookmarkedIds, <String>{'art-1'});
    });
  });
}
