// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/sources/api_client.dart';

/// Initialises Firebase once. Returns false (and logs) when the platform
/// config is missing, so a build without `google-services.json` still runs.
Future<bool> initializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    return true;
  } catch (error) {
    debugPrint('PushService: Firebase unavailable: $error');
    return false;
  }
}

/// Device registration for breaking-news pushes.
///
/// The server contract is `POST/DELETE /api/mobile/v1/devices` with
/// `{ token, platform }`; both require the caller's session token, which
/// [ApiClient] attaches only to SLNews hosts.
class PushService {
  PushService({
    required ApiClient client,
    required String baseUrl,
    Future<bool> Function()? ensureFirebase,
  }) : _register = ((String url, Map<String, dynamic> body) =>
           client.postJson(url, body)),
       _unregister = ((String url, Map<String, dynamic> body) =>
           client.deleteJson(url, body: body)),
       _baseUrl = baseUrl,
       _ensureFirebase = ensureFirebase ?? initializeFirebase;

  /// Test seam: no Firebase, no platform channels.
  @visibleForTesting
  PushService.forTransports({
    required Future<Object?> Function(String url, Map<String, dynamic> body)
    register,
    required Future<Object?> Function(String url, Map<String, dynamic> body)
    unregister,
    required Future<String?> Function() token,
    required Future<bool> Function() requestPermission,
    String baseUrl = 'https://example.invalid',
  }) : _register = register,
       _unregister = unregister,
       _token = token,
       _requestPermission = requestPermission,
       _baseUrl = baseUrl,
       _ensureFirebase = (() async => true),
       _testMode = true;

  final Future<Object?> Function(String url, Map<String, dynamic> body)
  _register;
  final Future<Object?> Function(String url, Map<String, dynamic> body)
  _unregister;
  final String _baseUrl;
  final Future<bool> Function() _ensureFirebase;
  bool _testMode = false;

  Future<String?> Function()? _token;
  Future<bool> Function()? _requestPermission;
  final StreamController<Map<String, dynamic>> _taps =
      StreamController<Map<String, dynamic>>.broadcast();
  FlutterLocalNotificationsPlugin? _notifications;
  StreamSubscription<RemoteMessage>? _foreground;

  /// Notification taps, for routing. Empty payloads are ignored.
  Stream<Map<String, dynamic>> get taps => _taps.stream;

  String get _devicesUrl =>
      '${_baseUrl.replaceAll(RegExp(r"/+$"), "")}/api/mobile/v1/devices';

  String get _platform => Platform.isIOS ? 'ios' : 'android';

  /// Requests permission, registers the device and starts foreground display.
  /// Returns false when Firebase is unavailable or permission was denied.
  Future<bool> enable() async {
    try {
      if (!await _ensureFirebase()) return false;
      final bool granted =
          await (_requestPermission ?? _requestPermissionReal)();
      if (!granted) return false;
      final String? token = await (_token ?? _tokenReal)();
      if (token == null || token.isEmpty) return false;
      await _register(_devicesUrl, <String, dynamic>{
        'token': token,
        'platform': _platform,
      });
      await _startNotifications();
      return true;
    } catch (error) {
      debugPrint('PushService: enable failed: $error');
      return false;
    }
  }

  /// Silent re-registration for an already-permitted device (app start).
  Future<void> ensureRegistered() async {
    try {
      if (!await _ensureFirebase()) return;
      final String? token = await (_token ?? _tokenReal)();
      if (token == null || token.isEmpty) return;
      await _register(_devicesUrl, <String, dynamic>{
        'token': token,
        'platform': _platform,
      });
      await _startNotifications();
    } catch (error) {
      debugPrint('PushService: ensureRegistered failed: $error');
    }
  }

  /// Removes this device so it stops receiving pushes.
  Future<void> disable() async {
    try {
      final String? token = await (_token ?? _tokenReal)();
      if (token == null || token.isEmpty) return;
      await _unregister(_devicesUrl, <String, dynamic>{
        'token': token,
        'platform': _platform,
      });
    } catch (error) {
      debugPrint('PushService: disable failed: $error');
    }
  }

  Future<bool> _requestPermissionReal() async {
    if (!Platform.isAndroid) {
      final NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }
    final NotificationSettings settings = await FirebaseMessaging.instance
        .requestPermission();
    return settings.authorizationStatus != AuthorizationStatus.denied;
  }

  Future<String?> _tokenReal() => FirebaseMessaging.instance
      // ignore: deprecated_member_use
      .getToken();

  Future<void> _startNotifications() async {
    if (_testMode) return;
    final FlutterLocalNotificationsPlugin plugin = _notifications ??=
        FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const InitializationSettings settings = InitializationSettings(
      android: android,
    );
    await plugin.initialize(settings: settings);
    _foreground ??= FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final RemoteNotification? notification = message.notification;
      if (notification == null) return;
      unawaited(
        plugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'breaking_news',
              'Breaking news',
              channelDescription: 'Breaking news and daily briefing alerts',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        ),
      );
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data.isNotEmpty) _taps.add(message.data);
    });
    final RemoteMessage? initial = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initial != null && initial.data.isNotEmpty) _taps.add(initial.data);
  }
}
