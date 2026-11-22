import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/utils/video_embed.dart';
import 'package:slnews_mobile/features/video/presentation/video_reel_page.dart';
import 'package:slnews_mobile/l10n/app_localizations.dart';

Widget _app(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('captions and fullscreen controls report taps', (
    WidgetTester tester,
  ) async {
    int captions = 0;
    int fullscreen = 0;

    await tester.pumpWidget(
      _app(
        ReelYoutubeControls(
          captionsEnabled: true,
          onToggleCaptions: () => captions++,
          onFullScreen: () => fullscreen++,
        ),
      ),
    );

    expect(find.byTooltip('Turn off captions'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.closed_caption));
    await tester.tap(find.byIcon(Icons.open_in_full));
    await tester.pump();

    expect(captions, 1);
    expect(fullscreen, 1);
  });

  testWidgets('the captions control reflects the on/off label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ReelYoutubeControls(
          captionsEnabled: false,
          onToggleCaptions: () {},
          onFullScreen: () {},
        ),
      ),
    );

    expect(find.byTooltip('Turn on captions'), findsOneWidget);
  });

  testWidgets('player controls are localized', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        ReelYoutubeControls(
          captionsEnabled: true,
          onToggleCaptions: () {},
          onFullScreen: () {},
        ),
        locale: const Locale('fr'),
      ),
    );

    expect(find.byTooltip('Désactiver les sous-titres'), findsOneWidget);
    expect(find.byTooltip('Plein écran'), findsOneWidget);
  });

  test('only addressable YouTube clips use the native player', () {
    final VideoPlayback youtube = resolvePlayback(
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );
    final VideoPlayback article = resolvePlayback(
      'https://slbc.example/news/some-story',
    );
    final VideoPlayback channel = resolvePlayback(
      'https://www.youtube.com/@slbcnews',
    );

    expect(canUseNativeYoutubePlayer(youtube), isTrue);
    expect(canUseNativeYoutubePlayer(article), isFalse);
    expect(canUseNativeYoutubePlayer(channel), isFalse);
  });
}
