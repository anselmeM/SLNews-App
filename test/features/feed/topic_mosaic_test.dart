import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/feed/presentation/widgets/topic_mosaic.dart';

/// The mosaic is the reference's two-column topic grid; its contract is simply
/// "show the labels, report the whole item when tapped".
void main() {
  testWidgets('renders the topic labels and reports the tapped item', (
    WidgetTester tester,
  ) async {
    final List<String> tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: TopicMosaic(
              items: const <TopicMosaicItem>[
                TopicMosaicItem(id: 'cars', label: 'Cars and Vehicles'),
                TopicMosaicItem(id: 'music', label: 'Music'),
                TopicMosaicItem(id: 'culture', label: 'Culture'),
              ],
              onOpen: (TopicMosaicItem item) => tapped.add(item.id),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cars and Vehicles'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Culture'), findsOneWidget);

    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();

    expect(tapped, <String>['music']);
  });

  testWidgets('caps the rail at maxItems', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: TopicMosaic(
              maxItems: 2,
              items: const <TopicMosaicItem>[
                TopicMosaicItem(id: 'cars', label: 'Cars and Vehicles'),
                TopicMosaicItem(id: 'music', label: 'Music'),
                TopicMosaicItem(id: 'culture', label: 'Culture'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cars and Vehicles'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Culture'), findsNothing);
  });
}
