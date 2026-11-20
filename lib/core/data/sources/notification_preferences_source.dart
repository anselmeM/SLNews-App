import '../../domain/models/digest_preferences.dart';
import '../sync/sync_api_config.dart';
import 'api_client.dart';

// ignore_for_file: prefer_initializing_formals

/// A place to persist digest preferences; faked in tests.
abstract interface class DigestPreferencesSink {
  Future<void> save(DigestPreferences preferences);
}

/// Writes the reader's digest preferences to the PWA API.
///
/// Delivery happens on the server, so this call is what makes Settings real.
/// The caller treats failures as offline: the local preference still applies to
/// the UI and is retried on the next change.
class DigestPreferencesSource implements DigestPreferencesSink {
  DigestPreferencesSource({required ApiClient client, String? baseUrl})
    : _client = client,
      _baseUrl = baseUrl ?? SyncApiConfig.fromEnvironment().baseUrl;

  final ApiClient _client;
  final String _baseUrl;

  Uri get endpoint =>
      Uri.parse('$_baseUrl/api/mobile/v1/notification-preferences');

  @override
  Future<void> save(DigestPreferences preferences) async {
    await _client.putJson(endpoint.toString(), preferences.toServerJson());
  }
}
