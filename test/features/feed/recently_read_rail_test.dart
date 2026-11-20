import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/reading_history_provider.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/feed/presentation/widgets/recently_read_rail.dart';

import 'support/fakes.dart';

void main() {
  final Article first = testArticle(id: 'a', title: 'First story read');
  final Article second = testArticle(id: 'b', title: 'Second story read');

  Future<void> pumpRail(
    WidgetTester tester, {
    InMemoryPreferencesStore? store,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          preferencesStoreProvider.overrideWithValue(
            store ??
                InMemoryPreferencesStore(<String, Object?>{
                  readingHistoryKey: jsonEncode(<String>['b', 'a']),
                }),
          ),
          articleRepositoryProvider.overrideWithValue(
            FakeArticleRepository(topStories: <Article>[first, second]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(child: RecentlyReadRail()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders recent stories in history order', (
    WidgetTester tester,
  ) async {
    await pumpRail(tester);

    expect(find.text('Recently read'), findsOneWidget);
    expect(find.text('Only on this device'), findsOneWidget);
    expect(find.text('First story read'), findsOneWidget);
    expect(find.text('Second story read'), findsOneWidget);

    // 'b' was the latest read, so it comes first in the rail.
    final Offset secondOffset = tester.getTopLeft(
      find.text('Second story read'),
    );
    final Offset firstOffset = tester.getTopLeft(find.text('First story read'));
    expect(secondOffset.dx, lessThan(firstOffset.dx));
  });

  testWidgets('renders nothing with an empty history', (
    WidgetTester tester,
  ) async {
    await pumpRail(tester, store: InMemoryPreferencesStore());

    expect(find.text('Recently read'), findsNothing);
  });
}
