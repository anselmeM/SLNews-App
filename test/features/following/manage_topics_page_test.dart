import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/controllers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/following/presentation/manage_topics_page.dart';
import 'package:slnews_mobile/features/following/presentation/widgets/catalogue_list.dart';

import '../feed/support/fakes.dart' show FakeUserStateRepository;
import 'support/fakes.dart';

/// Widget tests for Following -> Manage news topics.
void main() {
  const FollowTarget politics = FollowTarget(
    id: 'topic:politics',
    kind: FollowKind.topic,
    label: 'Politics',
    subtitle: 'Topic',
  );
  const FollowTarget business = FollowTarget(
    id: 'topic:business',
    kind: FollowKind.topic,
    label: 'Business',
    subtitle: 'Topic',
  );
  const FollowTarget sports = FollowTarget(
    id: 'topic:sports',
    kind: FollowKind.topic,
    label: 'Sports',
    subtitle: 'Topic',
  );
  const FollowTarget world = FollowTarget(
    id: 'topic:world',
    kind: FollowKind.topic,
    label: 'World',
    subtitle: 'Topic',
  );

  late InMemoryFollowingRepository following;
  late ProviderContainer container;

  setUp(() {
    following = InMemoryFollowingRepository(
      followed: <FollowTarget>[politics],
      catalogue: <FollowTarget>[politics, business, sports, world],
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
          home: const ManageTopicsPage(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('lists every news section as a followable topic', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Politics'), findsOneWidget);
    expect(find.text('Business'), findsOneWidget);
    expect(find.text('Sports'), findsOneWidget);
    expect(find.text('World'), findsOneWidget);
  });

  testWidgets('shows the followed topic ticked', (WidgetTester tester) async {
    await pumpPage(tester);

    expect(find.byIcon(Icons.check), findsOneWidget);
    final Finder politicsRow = find.ancestor(
      of: find.text('Politics'),
      matching: find.byType(InkWell),
    );
    expect(
      find.descendant(of: politicsRow, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
  });

  testWidgets('tapping a topic follows it', (WidgetTester tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('World'));
    await tester.pump();
    await tester.pump();

    expect(
      container.read(followingControllerProvider).isFollowed('topic:world'),
      isTrue,
    );

    final Finder worldRow = find.ancestor(
      of: find.text('World'),
      matching: find.byType(CatalogueCheckRow),
    );
    expect(
      find.descendant(of: worldRow, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
  });

  testWidgets('search narrows the list', (WidgetTester tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'bus');
    await tester.pump();

    expect(find.text('Business'), findsOneWidget);
    expect(find.text('Politics'), findsNothing);
  });
}
