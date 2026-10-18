import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'sentry_settings.dart';

/// Reports an unexpected error to Sentry when the build has a DSN.
///
/// Every failure is also logged locally, so a build without reporting still says
/// what happened. Callers pass a short `where` tag instead of a sentence: it is
/// what makes `list.filter(tag:where:sync)` useful in the Sentry UI.
void reportError(Object error, {StackTrace? stackTrace, String? where}) {
  debugPrint('SLNews error${where == null ? '' : ' [$where]'}: $error');
  if (!SentrySettings.fromEnvironment().isEnabled) return;

  Sentry.captureException(
    error,
    stackTrace: stackTrace,
    withScope: (Scope scope) {
      if (where != null) scope.setTag('where', where);
    },
  );
}

/// Sends a harmless event so a configured project can be verified by hand.
///
/// Only reachable from a debug build with reporting enabled; release builds hide
/// the Settings row that calls it.
Future<void> sendTestEvent() async {
  if (!SentrySettings.fromEnvironment().isEnabled) return;
  await Sentry.captureMessage('SLNews test event', level: SentryLevel.info);
}

/// Throws and captures a deliberate exception, the workflow Sentry's Flutter guide
/// recommends for verifying a project end to end.
Future<void> sendTestException() async {
  if (!SentrySettings.fromEnvironment().isEnabled) return;
  try {
    throw StateError('This is test exception');
  } catch (error, stackTrace) {
    await Sentry.captureException(error, stackTrace: stackTrace);
  }
}
