import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/routing/app_router.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';

import 'support/fakes.dart';
import 'support/test_harness.dart';

/// Integration check: the real shared router (bottom-navigation shell included)
/// must mount [ForYouPage] as tab 1 and render its content.
///
/// The focused widget tests use a hand-built router so they stay independent of
/// the other feature modules; this one proves the frozen wiring still works.
void main() {
  testWidgets('the shared router renders the For You feed', (
    WidgetTester tester,
  ) async {
    await useTallSurface(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: feedTestOverrides(
          articles: FakeArticleRepository(
            topStories: <Article>[
              testArticle(id: 'a', title: 'Integration headline'),
            ],
          ),
        ),
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: createAppRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Integration headline'), findsOneWidget);
    expect(find.text('For you'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
