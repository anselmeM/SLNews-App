import '../../domain/models/digest_preferences.dart';
import '../sync/sync_api_config.dart';
import 'api_client.dart';

// ignore_for_file: prefer_initializing_formals

/// Server side of the digest preferences; faked in tests.
abstract interface class DigestPreferencesGateway {
  /// Sends only the fields the reader changed, so a stale local value for a
  /// different field can never overwrite the server's saved choice.
  ///
  /// Contract: the PWA route must merge these fields into the stored document.
  /// A full-replacement PUT would erase the fields this patch omits.
  Future<void> save(Map<String, dynamic> fields);

  /// The account's saved preferences, or null when the server has none.
  Future<DigestPreferences?> fetch();
}

/// Reads and writes the reader's digest preferences on the PWA API.
///
/// Delivery happens on the server, so this is what makes Settings real. The
/// caller treats failures as offline: the local preference still applies and is
/// retried when the reader is signed in and connected.
class DigestPreferencesSource implements DigestPreferencesGateway {
  DigestPreferencesSource({required ApiClient client, String? baseUrl})
    : _client = client,
      _baseUrl = baseUrl ?? SyncApiConfig.fromEnvironment().baseUrl;

  final ApiClient _client;
  final String _baseUrl;

  Uri get endpoint =>
      Uri.parse('$_baseUrl/api/mobile/v1/notification-preferences');

  @override
  Future<void> save(Map<String, dynamic> fields) async {
    await _client.putJson(endpoint.toString(), fields);
  }

  @override
  Future<DigestPreferences?> fetch() async {
    final Object? payload = await _client.getJson(endpoint.toString());
    return parseServerPreferences(payload);
  }

  /// Decodes a GET payload; an empty object means the server has no saved
  /// preferences yet and must not reset the reader's local choices.
  static DigestPreferences? parseServerPreferences(Object? payload) {
    if (payload is! Map) return null;
    const Set<String> expected = <String>{
      DigestPreferences.digestCadenceField,
      DigestPreferences.quietHoursStartField,
      DigestPreferences.quietHoursEndField,
      DigestPreferences.timezoneOffsetField,
    };
    if (!expected.any(payload.containsKey)) return null;
    return DigestPreferences.fromServerJson(
      payload.map<String, dynamic>(
        (Object? key, Object? value) =>
            MapEntry<String, dynamic>('$key', value),
      ),
    );
  }
}
