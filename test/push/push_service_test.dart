import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/push/push_service.dart';

void main() {
  test('enable registers the device and returns true', () async {
    final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];
    final service = PushService.forTransports(
      register: (String url, Map<String, dynamic> body) async {
        calls.add(<String, dynamic>{'url': url, 'body': body});
        return null;
      },
      unregister: (_, _) async => null,
      token: () async => 'token-123',
      requestPermission: () async => true,
    );

    expect(await service.enable(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(calls, hasLength(1));
    expect(calls.single['url'], endsWith('/api/mobile/v1/devices'));
    expect(
      (calls.single['body'] as Map<String, dynamic>)['token'],
      'token-123',
    );
    expect(
      (calls.single['body'] as Map<String, dynamic>)['platform'],
      isIn(<String>['android', 'ios']),
    );
  });

  test('enable returns false when permission is denied', () async {
    final service = PushService.forTransports(
      register: (_, _) async => null,
      unregister: (_, _) async => null,
      token: () async => 'token-123',
      requestPermission: () async => false,
    );
    expect(await service.enable(), isFalse);
  });

  test('disable deletes the registration and swallows failures', () async {
    final List<String> urls = <String>[];
    final service = PushService.forTransports(
      register: (_, _) async => null,
      unregister: (String url, Map<String, dynamic> body) async {
        urls.add(url);
        throw StateError('offline');
      },
      token: () async => 'token-123',
      requestPermission: () async => true,
    );
    await service.disable();
    expect(urls.single, endsWith('/api/mobile/v1/devices'));
  });

  test('a missing token never registers', () async {
    final List<String> urls = <String>[];
    final service = PushService.forTransports(
      register: (String url, _) async => urls.add(url),
      unregister: (_, _) async => null,
      token: () async => null,
      requestPermission: () async => true,
    );
    expect(await service.enable(), isFalse);
    expect(urls, isEmpty);
  });
}
