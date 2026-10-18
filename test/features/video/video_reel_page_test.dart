import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/video_moment.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/utils/video_embed.dart';
import 'package:slnews_mobile/features/video/presentation/video_reel_page.dart';

/// The full-screen reel: one clip per vertical page, the whole caption visible,
/// and playback in-app (the web view is replaced by a stub in tests).
void main() {
  List<VideoMoment> reels() => <VideoMoment>[
    VideoMoment(
      id: 'video:first',
      title: 'Leone Stars step up training ahead of the AFCON qualifier',
      source: 'SLBC Sports',
      thumbnailUrl: '',
      url: 'https://youtu.be/dQw4w9WgXcQ',
      summary: 'The squad trained in Freetown ahead of the away leg.',
      publishedAt: DateTime.utc(2026, 10, 15),
    ),
    VideoMoment(
      id: 'video:second',
      title: 'Freetown residents assess damage after overnight flooding',
      source: 'SLBC News',
      thumbnailUrl: '',
      url: 'https://slbc.example/news/flooding',
      publishedAt: DateTime.utc(2026, 10, 14),
    ),
  ];

  /// Pushes the reel from a host page so the close button has something to pop.
  Future<void> pumpReel(
    WidgetTester tester, {
    String videoId = 'video:first',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => VideoReelPage(
                    videos: reels(),
                    videoId: videoId,
                    // Platform views cannot run in widget tests.
                    playerBuilder: (
                      BuildContext context,
                      VideoPlayback playback,
                    ) => const ColoredBox(color: Colors.black12),
                  ),
                ),
              ),
              child: const Text('open reel'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open reel'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the tapped clip and shows its whole caption', (
    WidgetTester tester,
  ) async {
    await pumpReel(tester);

    expect(
      find.text('Leone Stars step up training ahead of the AFCON qualifier'),
      findsOneWidget,
    );
    expect(find.text('SLBC Sports'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    // The rail card clipped long captions; the reel has room for all of it.
    final Text title = tester.widget<Text>(
      find.text('Leone Stars step up training ahead of the AFCON qualifier'),
    );
    expect(title.maxLines, isNull);
  });

  testWidgets('swiping up advances to the next clip', (
    WidgetTester tester,
  ) async {
    await pumpReel(tester);

    await tester.drag(find.byType(PageView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
    expect(
      find.text('Freetown residents assess damage after overnight flooding'),
      findsOneWidget,
    );
  });

  testWidgets('opens on a later clip when the reel is given its id', (
    WidgetTester tester,
  ) async {
    await pumpReel(tester, videoId: 'video:second');

    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('an unknown id starts at the top instead of failing', (
    WidgetTester tester,
  ) async {
    await pumpReel(tester, videoId: 'video:missing');

    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('closing the reel pops the route', (WidgetTester tester) async {
    await pumpReel(tester);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(VideoReelPage), findsNothing);
    expect(find.text('open reel'), findsOneWidget);
  });
}
