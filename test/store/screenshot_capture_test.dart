import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/app.dart';
import 'package:slnews_mobile/core/providers/app_bootstrap.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/routing/app_router.dart';
import 'package:slnews_mobile/core/routing/app_routes.dart';

/// Writes clean device renders for the Play listing.
///
/// Opt-in, because it writes PNGs instead of comparing them:
///
///     S L N E W S _ S T O R E _ C A P T U R E S = 1 \
///         flutter test test/store/screenshot_capture_test.dart
///
/// (the variable is read without spaces above; the underscore form is used in
/// the command). Output goes to `store/play/captures/`, where
/// `tools/generate_store_assets.py` composes it into listing screenshots.
///
/// The offline banner is scrolled past before capture: it is honest in the app
/// but reads as a defect on a store listing. Remote images still render as the
/// design-system placeholder under `flutter test`, so a real-device capture is
/// the better final source - drop files with the same names into
/// `store/play/captures/` and regenerate.
void main() {
  final bool enabled = Platform.environment['SLNEWS_STORE_CAPTURES'] == '1';
  final GlobalKey captureKey = GlobalKey();
  late ProviderContainer container;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final String tempDir = Directory.systemTemp
        .createTempSync('slnews_capture_')
        .path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall call) async => tempDir,
        );

    final FontLoader textLoader = FontLoader('SLNewsSans');
    textLoader.addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    await textLoader.load();

    final FontLoader iconLoader = FontLoader('MaterialIcons');
    iconLoader.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await iconLoader.load();
  });

  /// Bounded pumping: the shimmer skeletons animate forever by design.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  void drain(WidgetTester tester) {
    while (tester.takeException() != null) {
      // Platform channels a widget test cannot satisfy; the renders fall back.
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    // Logical reference device: 1080 x 2202 at DPR 2.75.
    tester.view.physicalSize = const Size(1080, 2202);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final AppBootstrap bootstrap = await AppBootstrap.create(
      allowPersistence: false,
    );
    container = bootstrap.container;
    addTearDown(container.dispose);

    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: UncontrolledProviderScope(
          container: container,
          child: const SlNewsApp(),
        ),
      ),
    );
    await settle(tester);
    drain(tester);
  }

  Future<void> writeCapture(WidgetTester tester, String name) async {
    drain(tester);
    final RenderRepaintBoundary boundary =
        captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // toImage/PNG encoding are real async engine work; inside the fake async zone
    // of a widget test they never complete without runAsync.
    await tester.runAsync(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: 2.75);
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (data == null) return;
      // flutter test runs with the package root as the working directory.
      final File file = File('store/play/captures/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data.buffer.asUint8List());
    });
  }

  /// Scrolls the offline banner out of frame.
  Future<void> scrollPastBanner(WidgetTester tester) async {
    final Finder scrollable = find.byType(CustomScrollView).first;
    if (scrollable.evaluate().isEmpty) return;
    await tester.drag(scrollable, const Offset(0, -140));
    await settle(tester);
  }

  testWidgets('capture: For You', (WidgetTester tester) async {
    await pumpApp(tester);
    await scrollPastBanner(tester);
    await writeCapture(tester, 'for_you');
  }, skip: !enabled);

  testWidgets('capture: News', (WidgetTester tester) async {
    await pumpApp(tester);
    container.read(appRouterProvider).go(AppRoutes.news);
    await settle(tester);
    await scrollPastBanner(tester);
    await writeCapture(tester, 'news');
  }, skip: !enabled);

  testWidgets('capture: Sports', (WidgetTester tester) async {
    await pumpApp(tester);
    container.read(appRouterProvider).go(AppRoutes.sports);
    await settle(tester);
    await scrollPastBanner(tester);
    await writeCapture(tester, 'sports');
  }, skip: !enabled);

  testWidgets('capture: Following', (WidgetTester tester) async {
    await pumpApp(tester);
    container.read(appRouterProvider).go(AppRoutes.following);
    await settle(tester);
    await scrollPastBanner(tester);
    await writeCapture(tester, 'following');
  }, skip: !enabled);

  testWidgets('capture: article reader', (WidgetTester tester) async {
    await pumpApp(tester);
    final String id =
        (await container.read(articleRepositoryProvider).topStories()).first.id;
    container.read(appRouterProvider).push(AppRoutes.articleFor(id));
    await settle(tester);
    await writeCapture(tester, 'article');
  }, skip: !enabled);

  testWidgets('capture: Top stories section', (WidgetTester tester) async {
    await pumpApp(tester);
    container.read(appRouterProvider).push(AppRoutes.topStories);
    await settle(tester);
    await writeCapture(tester, 'section');
  }, skip: !enabled);

  testWidgets('capture: search results', (WidgetTester tester) async {
    await pumpApp(tester);
    container.read(appRouterProvider).go(AppRoutes.search);
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'leone');
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    await writeCapture(tester, 'search');
  }, skip: !enabled);
}
