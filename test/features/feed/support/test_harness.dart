import 'package:flutter/material.dart';
// `Override` lives in the misc entrypoint of Riverpod 3.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/ad_unit.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/controllers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';

import 'fakes.dart';

/// Repository overrides shared by every Feed/Bookmarks widget test.
///
/// Overriding the repositories (rather than the Notifiers) keeps the real
/// controllers in play, so the tests exercise the same wiring the app uses.
List<Override> feedTestOverrides({
  required FakeArticleRepository articles,
  FakeUserStateRepository? userState,
  FakeWeatherRepository? weather,
  List<AdUnit> ads = const <AdUnit>[],
}) {
  return <Override>[
    articleRepositoryProvider.overrideWithValue(articles),
    userStateProvider.overrideWithValue(userState ?? FakeUserStateRepository()),
    weatherRepositoryProvider.overrideWithValue(
      weather ?? FakeWeatherRepository(),
    ),
    sportsRepositoryProvider.overrideWithValue(FakeSportsRepository()),
    followingRepositoryProvider.overrideWithValue(FakeFollowingRepository()),
    notificationRepositoryProvider.overrideWithValue(
      FakeNotificationRepository(),
    ),
    adRepositoryProvider.overrideWithValue(FakeAdRepository(rotation: ads)),
    // Pull-to-refresh is a platform concern; stubbing it keeps the tests off
    // the network entirely.
    refreshFeedsProvider.overrideWithValue(() async {}),
  ];
}

/// Gives the test a phone-width but very tall canvas so feed content below the
/// hero carousel is built and hit-testable without scrolling first.
///
/// The window is sized in physical pixels, so the logical size is
/// `physicalSize / devicePixelRatio`.
Future<void> useTallSurface(
  WidgetTester tester, {
  Size size = const Size(390, 2200),
}) async {
  const double ratio = 3;
  tester.view.devicePixelRatio = ratio;
  tester.view.physicalSize = size * ratio;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Wraps [child] in the app theme with an optional text-scale override.
Widget themedChild(Widget child, {double textScaler = 1}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScaler)),
        child: child,
      ),
    ),
  );
}
