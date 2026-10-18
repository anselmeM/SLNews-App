import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 keeps `Override` out of the main entrypoint.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/widgets/sl_page_scaffold.dart';

import '../../features/feed/support/fakes.dart';

/// Every tab root renders through [SlPageScaffold], so the offline banner is
/// injected once here instead of being re-implemented per page.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool offline,
    bool showOfflineBanner = true,
    DateTime? lastSyncedAt,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          articleRepositoryProvider.overrideWithValue(
            FakeArticleRepository(
              isOffline: offline,
              lastSyncedAt: lastSyncedAt,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: SlPageScaffold(
            title: 'News',
            showOfflineBanner: showOfflineBanner,
            slivers: const <Widget>[SliverToBoxAdapter(child: Text('a story'))],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an offline repository shows the banner with the sync age', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      offline: true,
      lastSyncedAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

    expect(find.textContaining('Offline'), findsOneWidget);
    expect(find.textContaining('updated'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);
  });

  testWidgets('an online repository shows no banner', (
    WidgetTester tester,
  ) async {
    await pump(tester, offline: false);

    expect(find.textContaining('Offline'), findsNothing);
  });

  testWidgets('pages can opt out of the banner', (WidgetTester tester) async {
    await pump(tester, offline: true, showOfflineBanner: false);

    expect(find.textContaining('Offline'), findsNothing);
  });

  testWidgets('without storage the banner stays quiet instead of failing', (
    WidgetTester tester,
  ) async {
    // No repository override: the provider throws UnimplementedError, which the
    // status helper turns into "online" rather than a crash.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SlPageScaffold(
            title: 'News',
            slivers: <Widget>[SliverToBoxAdapter(child: Text('a story'))],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Offline'), findsNothing);
    expect(find.text('a story'), findsOneWidget);
  });
}
