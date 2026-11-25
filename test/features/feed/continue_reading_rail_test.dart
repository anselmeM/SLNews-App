import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/personalization_profile.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/feed/presentation/widgets/continue_reading_rail.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('shows unfinished stories with progress', (
    WidgetTester tester,
  ) async {
    final Article story = testArticle(
      id: 'story-1',
      title: 'Budget passes',
      categoryId: 'politics',
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        preferencesStoreProvider.overrideWithValue(InMemoryPreferencesStore()),
        articleRepositoryProvider.overrideWithValue(
          FakeArticleRepository(topStories: <Article>[story]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(personalizationProfileProvider.notifier)
        .recordRead(story, dwell: const Duration(seconds: 30), progress: 0.4);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(child: ContinueReadingRail()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue reading'), findsOneWidget);
    expect(find.text('Pick up where you left off'), findsOneWidget);
    expect(find.text('Budget passes'), findsOneWidget);
    expect(find.text('40% read'), findsOneWidget);
  });

  testWidgets('disappears when nothing is unfinished', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        preferencesStoreProvider.overrideWithValue(InMemoryPreferencesStore()),
        articleRepositoryProvider.overrideWithValue(FakeArticleRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(child: ContinueReadingRail()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue reading'), findsNothing);
  });
}
