import 'package:flutter/foundation.dart';

/// Central debug logger.
///
/// [debugPrint] is not stripped from release builds; routing every diagnostic
/// through one gate keeps release logs quiet and gives a single place to add
/// Sentry breadcrumbs later.
abstract final class AppLog {
  static void debug(String message) {
    if (kDebugMode) debugPrint(message);
  }
}
