import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 keeps `Override` out of the main entrypoint.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/video_moment.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/utils/video_embed.dart';
import 'package:slnews_mobile/features/video/presentation/video_reel_page.dart';

import '../feed/support/fakes.dart';

/// The full-screen reel, laid out like the reference: full-bleed clip, back
/// chevron, action rail (mute / full screen / like), publisher badge, and a white
/// caption strip with a segmented position indicator.
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

  /// Pushes the reel from a host page so the back button has something to pop.
  Future<void> pumpReel(
    WidgetTester tester, {
    String videoId = 'video:first',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          userStateProvider.overrideWithValue(FakeUserStateRepository()),
          videoMomentsProvider.overrideWith((Ref ref) async => reels()),
        ],
        child: MaterialApp(
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
      ),
    );
    await tester.tap(find.text('open reel'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the caption strip, publisher badge and position', (
    WidgetTester tester,
  ) async {
    await pumpReel(tester);

    expect(
      find.text('Leone Stars step up training ahead of the AFCON qualifier'),
      findsOneWidget,
    );
    expect(find.text('SLBC Sports'), findsOneWidget);
    final ReelSegments segments = tester.widget<ReelSegments>(
      find.byType(ReelSegments),
    );
    expect(segments.position, 1);
    expect(segments.total, 2);
  });

  testWidgets('the rail offers mute, full screen and like', (
    WidgetTester tester,
  ) async {
    await pumpReel(tester);

    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(find.byIcon(Icons.open_in_full), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
  });

  testWidgets('mute toggles from the rail', (WidgetTester tester) async {
    await pumpReel(tester);

    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.volume_off), findsOneWidget);
  });

  testWidgets('like toggles and fills the thumb', (WidgetTester tester) async {
    await pumpReel(tester);

    await tester.tap(find.byIcon(Icons.thumb_up_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.thumb_up), findsOneWidget);
  });

  testWidgets('tapping the clip pauses it and shows the play control', (
    WidgetTester tester,
  ) async {
    await pumpReel(tester);

    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });

  testWidgets('swiping up advances to the next clip', (
    WidgetTester tester,
  ) async {
    await pumpReel(tester);

    await tester.drag(find.byType(PageView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(
      find.text('Freetown residents assess damage after overnight flooding'),
      findsOneWidget,
    );
    expect(tester.widget<ReelSegments>(find.byType(ReelSegments)).position, 2);
  });

  testWidgets('opens on a later clip when the reel is given its id', (
    WidgetTester tester,
  ) async {
    await pumpReel(tester, videoId: 'video:second');

    expect(tester.widget<ReelSegments>(find.byType(ReelSegments)).position, 2);
  });

  testWidgets('an unknown id starts at the top instead of failing', (
    WidgetTester tester,
  ) async {
    await pumpReel(tester, videoId: 'video:missing');

    expect(tester.widget<ReelSegments>(find.byType(ReelSegments)).position, 1);
  });

  testWidgets('the back chevron leaves the reel', (WidgetTester tester) async {
    await pumpReel(tester);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(find.byType(VideoReelPage), findsNothing);
    expect(find.text('open reel'), findsOneWidget);
  });
}
