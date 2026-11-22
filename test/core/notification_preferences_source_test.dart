import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/api_client.dart';
import 'package:slnews_mobile/core/data/sources/notification_preferences_source.dart';
import 'package:slnews_mobile/core/domain/models/digest_preferences.dart';

class _RecordingApi extends ApiClient {
  final List<Map<String, dynamic>> puts = <Map<String, dynamic>>[];
  Object? getPayload;

  @override
  Future<dynamic> putJson(
    String url,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    puts.add(body);
    return <String, dynamic>{};
  }

  @override
  Future<dynamic> getJson(String url, {Map<String, dynamic>? query}) async =>
      getPayload;
}

void main() {
  group('DigestPreferencesSource', () {
    test('sends only the patched fields', () async {
      final _RecordingApi api = _RecordingApi();
      final DigestPreferencesSource source = DigestPreferencesSource(
        client: api,
        baseUrl: 'https://example.test',
      );

      await source.save(<String, dynamic>{
        DigestPreferences.digestCadenceField: DigestPreferences.offCadence,
      });

      expect(api.puts.single, <String, dynamic>{'digestCadence': 'off'});
    });

    test('decodes a complete server payload', () async {
      final _RecordingApi api = _RecordingApi()
        ..getPayload = <String, dynamic>{
          'digestCadence': 'off',
          'quietHoursStart': 1260,
          'quietHoursEnd': 360,
          'timezoneOffsetMinutes': 60,
        };
      final DigestPreferencesSource source = DigestPreferencesSource(
        client: api,
        baseUrl: 'https://example.test',
      );

      final DigestPreferences? prefs = await source.fetch();

      expect(
        prefs,
        const DigestPreferences(
          digestEnabled: false,
          quietHoursStart: 1260,
          quietHoursEnd: 360,
          timezoneOffsetMinutes: 60,
        ),
      );
    });

    test('an empty payload does not overwrite local preferences', () async {
      final _RecordingApi api = _RecordingApi()
        ..getPayload = <String, dynamic>{};
      final DigestPreferencesSource source = DigestPreferencesSource(
        client: api,
        baseUrl: 'https://example.test',
      );

      expect(await source.fetch(), isNull);
      expect(DigestPreferencesSource.parseServerPreferences(null), isNull);
      expect(
        DigestPreferencesSource.parseServerPreferences(<Object?>[]),
        isNull,
      );
    });
  });
}
