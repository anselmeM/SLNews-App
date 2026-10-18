import 'package:flutter/foundation.dart';

/// Crash-reporting configuration, supplied at build time.
///
/// The DSN is a client key, not a secret, but it still belongs in configuration
/// rather than in source: a build without `--dart-define=SENTRY_DSN=…` simply
/// runs with reporting disabled, which is what keeps tests, contributor builds
/// and the app runnable before a Sentry project exists.
@immutable
class SentrySettings {
  const SentrySettings({
    required this.dsn,
    required this.environment,
    required this.release,
    this.tracesSampleRate = 0.05,
  });

  /// Reads the compile-time configuration:
  ///   `--dart-define=SENTRY_DSN=…`
  ///   `--dart-define=SENTRY_ENV=production|staging|development`
  ///   `--dart-define=SLNEWS_RELEASE=slnews-mobile@1.0.0+2`
  factory SentrySettings.fromEnvironment() => SentrySettings(
    dsn: const String.fromEnvironment('SENTRY_DSN'),
    environment: const String.fromEnvironment(
      'SENTRY_ENV',
      defaultValue: kReleaseMode ? 'production' : 'development',
    ),
    release: const String.fromEnvironment(
      'SLNEWS_RELEASE',
      defaultValue: 'slnews-mobile@1.0.0+2',
    ),
  );

  final String dsn;
  final String environment;
  final String release;

  /// Traces are sampled low: crash reports are the point, not full APM.
  final double tracesSampleRate;

  bool get isEnabled => dsn.trim().isNotEmpty;

  /// Options as a plain map, so the contract is testable without initialising
  /// the SDK or touching the network.
  @visibleForTesting
  Map<String, Object?> toOptionsMap() => <String, Object?>{
    'dsn': dsn,
    'environment': environment,
    'release': release,
    'tracesSampleRate': tracesSampleRate,
    // Never attach personal data: no IP address, no email, no request bodies.
    'sendDefaultPii': false,
    'attachStacktrace': true,
    'enableAutoSessionTracking': true,
  };
}
