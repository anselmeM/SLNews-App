import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/widgets/sl_network_image.dart';

void main() {
  testWidgets('renders editorial artwork when there is no image', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 140,
            child: SlNetworkImage(
              seed: 'story-1',
              placeholderLabel: 'SLT',
              fallbackIcon: Icons.sports_soccer,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.sports_soccer), findsOneWidget);
    expect(find.text('SLT'), findsOneWidget);
  });
}
