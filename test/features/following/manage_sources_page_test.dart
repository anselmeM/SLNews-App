import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/controllers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/following/presentation/manage_sources_page.dart';
import 'package:slnews_mobile/features/following/presentation/widgets/catalogue_list.dart';

import '../feed/support/fakes.dart' show FakeUserStateRepository;
import 'support/fakes.dart';

/// Widget tests for Following -> Manage news sources.
void main() {
  const FollowTarget awoko = FollowTarget(
    id: 'publisher:awoko',
    kind: FollowKind.publisher,
    label: 'Awoko Newspaper',
    subtitle: 'Sierra Leone',
  );
  const FollowTarget politico = FollowTarget(
    id: 'publisher:politicosl',
    kind: FollowKind.publisher,
    label: 'Politico SL',
    subtitle: 'Sierra Leone',
  );
  const FollowTarget bbc = FollowTarget(
    id: 'publisher:bbcafrica',
    kind: FollowKind.publisher,
    label: 'BBC News Africa',
    subtitle: 'Wire service',
  );

  late InMemoryFollowingRepository following;
  late ProviderContainer container;

  setUp(() {
    following = InMemoryFollowingRepository(
      followed: <FollowTarget>[politico],
      catalogue: <FollowTarget>[awoko, politico, bbc],
    );
    container = ProviderContainer(
      overrides: [
        followingRepositoryProvider.overrideWithValue(following),
        userStateProvider.overrideWithValue(FakeUserStateRepository()),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ManageSourcesPage(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('lists every publisher in the catalogue, not just suggestions', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Awoko Newspaper'), findsOneWidget);
    expect(find.text('Politico SL'), findsOneWidget);
    expect(find.text('BBC News Africa'), findsOneWidget);
    expect(find.text('Wire service'), findsOneWidget);
  });

  testWidgets('preselects the sources the reader already follows', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    // One followed source -> exactly one ticked row.
    expect(find.byIcon(Icons.check), findsOneWidget);
    final Finder politicoRow = find.ancestor(
      of: find.text('Politico SL'),
      matching: find.byType(InkWell),
    );
    expect(
      find.descendant(of: politicoRow, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
  });

  testWidgets('tapping a row follows the source', (WidgetTester tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Awoko Newspaper'));
    await tester.pump();
    await tester.pump();

    expect(
      following.toggleLog.map((FollowTarget t) => t.id),
      contains('publisher:awoko'),
    );
    expect(
      container.read(followingControllerProvider).isFollowed('publisher:awoko'),
      isTrue,
    );

    final Finder awokoRow = find.ancestor(
      of: find.text('Awoko Newspaper'),
      matching: find.byType(CatalogueCheckRow),
    );
    expect(
      find.descendant(of: awokoRow, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
  });

  testWidgets('search narrows the list', (WidgetTester tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'bbc');
    await tester.pump();

    expect(find.text('BBC News Africa'), findsOneWidget);
    expect(find.text('Awoko Newspaper'), findsNothing);
  });
}
