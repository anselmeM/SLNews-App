import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/observability/error_reporter.dart';
import 'package:slnews_mobile/core/observability/sentry_settings.dart';

/// Crash reporting is configuration, not a feature: an empty DSN must leave the
/// app exactly as it behaved before Sentry existed.
void main() {
  group('SentrySettings', () {
    test('a build without a DSN has reporting disabled', () {
      const SentrySettings settings = SentrySettings(
        dsn: '',
        environment: 'development',
        release: 'slnews-mobile@test',
      );

      expect(settings.isEnabled, isFalse);
    });

    test('a build with a DSN is enabled and maps to the SDK options', () {
      const SentrySettings settings = SentrySettings(
        dsn: 'https://public@o1.ingest.sentry.io/2',
        environment: 'production',
        release: 'slnews-mobile@1.0.0+2',
      );

      expect(settings.isEnabled, isTrue);
      final Map<String, Object?> options = settings.toOptionsMap();
      expect(options['dsn'], settings.dsn);
      expect(options['environment'], 'production');
      expect(options['release'], 'slnews-mobile@1.0.0+2');
      expect(options['tracesSampleRate'], 0.05);
      expect(options['sendDefaultPii'], isFalse);
      expect(options['attachStacktrace'], isTrue);
    });
  });

  group('reportError', () {
    test('does nothing but log when reporting is disabled', () {
      // fromEnvironment in the test runner has no SENTRY_DSN dart-define.
      expect(
        () => reportError(StateError('boom'), where: 'test'),
        returnsNormally,
      );
    });

    test('accepts a stack trace and a location tag', () {
      final StackTrace trace = StackTrace.current;
      expect(
        () => reportError(StateError('boom'), stackTrace: trace, where: 'sync'),
        returnsNormally,
      );
    });
  });
}
