import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/video_moment.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/widgets/video_moment_card.dart';

/// The card carries the outlet's mark and, when the payload supplies one, the
/// clip length - the two badges the reference puts on a video tile.
void main() {
  VideoMoment video({Duration? duration}) => VideoMoment(
    id: 'v1',
    title: 'King hails special connection with Wales',
    source: 'PA Media',
    thumbnailUrl: '',
    url: 'https://youtu.be/dQw4w9WgXcQ',
    duration: duration,
  );

  Future<void> pump(WidgetTester tester, VideoMoment moment) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: VideoMomentCard(video: moment, width: 220, height: 320),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the outlet badge and the play glyph', (
    WidgetTester tester,
  ) async {
    await pump(tester, video());

    expect(find.text('PA Media'), findsOneWidget);
    expect(find.text('P'), findsOneWidget, reason: 'monogram disc');
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('prints the clip length when it is known', (
    WidgetTester tester,
  ) async {
    await pump(tester, video(duration: const Duration(seconds: 65)));

    expect(find.text('1:05'), findsOneWidget);
  });

  testWidgets('prints no time when the payload has none', (
    WidgetTester tester,
  ) async {
    await pump(tester, video());

    expect(find.text('0:00'), findsNothing);
    // No trailing time label: the outlet badge is the last thing on the row.
    expect(find.text('PA Media'), findsOneWidget);
  });

  test('formats clip lengths', () {
    expect(durationLabel(const Duration(seconds: 5)), '0:05');
    expect(durationLabel(const Duration(seconds: 65)), '1:05');
    expect(durationLabel(const Duration(seconds: 3723)), '1:02:03');
  });
}
