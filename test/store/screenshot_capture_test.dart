import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/app.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/domain/repositories/following_repository.dart';
import 'package:slnews_mobile/core/providers/app_bootstrap.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/controllers.dart';
import 'package:slnews_mobile/core/routing/app_router.dart';
import 'package:slnews_mobile/core/routing/app_routes.dart';
import 'package:slnews_mobile/core/widgets/sl_network_image.dart';

/// Writes clean device renders for the Play listing.
///
/// Opt-in, because it writes PNGs instead of comparing them:
///
///     $env:SLNEWS_STORE_CAPTURES = '1'
///     flutter test test/store/screenshot_capture_test.dart
///
/// Output goes to `store/play/captures/`, where
/// `tools/generate_store_assets.py` composes it into listing screenshots.
///
/// Widget tests cannot perform network requests, so the photos come from
/// `test/store/images/` through [SlNetworkImage.debugImageProvider]. They are
/// illustrative fixtures, not the publisher photography a real device shows;
/// for final listing art drop real captures with the same names into
/// `store/play/captures/` and rerun the generator. `docs/STORE-SCREENSHOTS.md`
/// has the device procedure.
void main() {
  final bool enabled = Platform.environment['SLNEWS_STORE_CAPTURES'] == '1';
  tearDownAll(() => SlNetworkImage.debugImageProvider = null);
  final GlobalKey captureKey = GlobalKey();
  late ProviderContainer container;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _installFixtureImages();
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
    await container.read(userStateProvider).setOnboardingCompleted(true);
    await _seedRealisticFollowing(container);

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
    // MemoryImage decodes off the fake clock; give it real time, then pump the
    // decoded frame into the widget tree before capturing.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1800)),
    );
    await settle(tester);
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
    await tester.pump(const Duration(milliseconds: 1800));
    await settle(tester);
    await writeCapture(tester, 'search');
  }, skip: !enabled);
}

/// Serves the fixture photos to every remote image request. Widget tests cannot
/// use `CachedNetworkImage`, so the capture build swaps in local file images.
void _installFixtureImages() {
  final Directory dir = Directory('test/store/images');
  if (!dir.existsSync()) return;
  final List<File> files = dir.listSync().whereType<File>().where((File file) {
    final String path = file.path.toLowerCase();
    return path.endsWith('.jpg') || path.endsWith('.png');
  }).toList()..sort((File a, File b) => a.path.compareTo(b.path));
  if (files.isEmpty) return;

  // MemoryImage, not FileImage: a widget test's fake async zone can leave file
  // reads pending, while pre-read bytes decode reliably.
  final Map<String, Uint8List> bySeed = <String, Uint8List>{
    for (final File file in files)
      file.uri.pathSegments.last.replaceAll(RegExp(r'\.(jpg|png)$'), ''): file
          .readAsBytesSync(),
  };
  final Uint8List first = bySeed.values.first;

  // Fixture files are named after the seed URL segment (`.../seed/<seed>/...`),
  // so the same story always gets the same photo across captures. Bytes are
  // pre-read because a widget test's fake async zone can leave file reads
  // pending, while MemoryImage decodes reliably.
  SlNetworkImage.debugImageProvider = (String url) {
    final Uri? uri = Uri.tryParse(url);
    final List<String> segments = uri?.pathSegments ?? const <String>[];
    final int seedIndex = segments.indexOf('seed');
    final String? seed = seedIndex >= 0 && seedIndex + 1 < segments.length
        ? segments[seedIndex + 1]
        : null;
    final Uint8List? bytes = seed == null ? null : bySeed[seed];
    return MemoryImage(bytes ?? first);
  };
}

/// A believable reader state: four local teams, a league, three topics and two
/// publishers. The old capture followed the entire catalogue, which made every
/// row say "Following" — a bug that had already been fixed in the app.
Future<void> _seedRealisticFollowing(ProviderContainer container) async {
  final FollowingRepository repository = container.read(
    followingRepositoryProvider,
  );
  Iterable<FollowTarget> ofKind(FollowKind kind, int count) => repository
      .catalogue
      .where((FollowTarget target) => target.kind == kind)
      .take(count);

  final List<FollowTarget> targets = <FollowTarget>[
    ...ofKind(FollowKind.team, 4),
    ...ofKind(FollowKind.league, 1),
    ...ofKind(FollowKind.topic, 3),
    ...ofKind(FollowKind.publisher, 2),
  ];
  for (final FollowTarget target in targets) {
    await repository.follow(target);
  }
  container.invalidate(followingControllerProvider);
}
