import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/widgets/fade_slide_in.dart';

/// Entrance animation for blocks of content: fades in while rising, runs once,
/// and is skipped outright when the platform asks for reduced motion.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    Duration delay = Duration.zero,
    bool reducedMotion = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: Scaffold(
            body: FadeSlideIn(delay: delay, child: const Text('section')),
          ),
        ),
      ),
    );
  }

  double opacityOf(WidgetTester tester) =>
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

  testWidgets('starts hidden and settles fully visible', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    expect(opacityOf(tester), 0);

    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);
  });

  testWidgets('waits for its stagger delay', (WidgetTester tester) async {
    await pump(tester, delay: const Duration(milliseconds: 80));

    await tester.pump(const Duration(milliseconds: 40));
    expect(opacityOf(tester), 0);

    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);
  });

  testWidgets('reduced motion shows the content immediately', (
    WidgetTester tester,
  ) async {
    await pump(tester, reducedMotion: true);
    await tester.pump();

    expect(opacityOf(tester), 1);
  });
}
