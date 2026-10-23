import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/observability/error_reporter.dart';
import 'core/observability/sentry_settings.dart';
import 'core/providers/app_bootstrap.dart';
import 'core/push/push_service.dart';

/// Entry point.
///
/// Local storage and the repository graph are opened before the first frame so
/// the UI only ever renders against a fully wired, offline-capable app.
///
/// Crash reporting is opt-in through the build: with a `SENTRY_DSN` dart-define
/// the app starts inside Sentry's error handlers; without one it starts exactly
/// as before, which is what keeps tests and contributor builds offline.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never block the first frame on Firebase: verification/registration runs
  // lazily from PushService when the reader first interacts with push.
  unawaited(initializeFirebase());

  final SentrySettings sentry = SentrySettings.fromEnvironment();
  if (!sentry.isEnabled) {
    await _bootstrapAndRun();
    return;
  }

  await SentryFlutter.init((SentryFlutterOptions options) {
    options.dsn = sentry.dsn;
    options.environment = sentry.environment;
    options.release = sentry.release;
    options.tracesSampleRate = sentry.tracesSampleRate;
    // Crash reports only: no IP address, no user identity, no screenshots.
    options.sendDefaultPii = false;
    options.attachStacktrace = true;
    options.attachScreenshot = false;
  }, appRunner: _bootstrapAndRun);
}

Future<void> _bootstrapAndRun() async {
  try {
    final AppBootstrap bootstrap = await AppBootstrap.create();
    runApp(
      UncontrolledProviderScope(
        container: bootstrap.container,
        child: const SlNewsApp(),
      ),
    );
  } catch (error, stackTrace) {
    // A failure this early has no UI to show the error in; report it and start
    // a minimal app so the reader is not left with a blank screen.
    reportError(error, stackTrace: stackTrace, where: 'bootstrap');
    runApp(const _BootstrapFailureApp());
  }
}

/// Last-resort screen when storage or the repository graph cannot open.
class _BootstrapFailureApp extends StatelessWidget {
  const _BootstrapFailureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const <Widget>[
                Icon(Icons.error_outline, size: 40),
                SizedBox(height: 16),
                Text(
                  'SLNews could not start on this device.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Please reinstall the app. If it keeps happening, contact support.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
