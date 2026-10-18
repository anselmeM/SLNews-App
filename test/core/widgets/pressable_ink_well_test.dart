import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/widgets/pressable_ink_well.dart';

/// The theme turns the splash off, so the dip is the only press feedback a card
/// gives; these tests pin that it happens and that it never eats the tap.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onTap,
    double scale = 0.97,
    bool tappable = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: PressableInkWell(
              onTap: tappable ? (onTap ?? () {}) : null,
              scale: scale,
              child: const SizedBox(
                width: 200,
                height: 120,
                child: Text('card'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  AnimatedScale animatedScale(WidgetTester tester) =>
      tester.widget<AnimatedScale>(find.byType(AnimatedScale));

  testWidgets('dips under the finger and springs back', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    expect(animatedScale(tester).scale, 1);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.text('card')),
    );
    await tester.pump();
    expect(animatedScale(tester).scale, 0.97);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(animatedScale(tester).scale, 1);
  });

  testWidgets('the tap still reaches the InkWell', (WidgetTester tester) async {
    int taps = 0;
    await pump(tester, onTap: () => taps++);

    await tester.tap(find.text('card'));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('a cancelled gesture does not leave the card shrunk', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.text('card')),
    );
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(animatedScale(tester).scale, 1);
  });

  testWidgets('a non-interactive card does not dip', (
    WidgetTester tester,
  ) async {
    await pump(tester, tappable: false);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.text('card')),
    );
    await tester.pump();
    expect(animatedScale(tester).scale, 1);
    await gesture.up();
  });
}
