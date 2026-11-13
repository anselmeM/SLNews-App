// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/sources/api_client.dart';
import '../domain/models/app_settings.dart';
import 'push_segments.dart';

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
  /// Persisted set of applied FCM topics, reconciled on the next launch.
  static const String topicsPrefKey = 'push.topics';

  PushService({
    required ApiClient client,
    required String baseUrl,
    Future<bool> Function()? ensureFirebase,
    Set<String> initialTopics = const <String>{},
    Future<void> Function(Set<String>)? persistTopics,
  }) : _register = ((String url, Map<String, dynamic> body) =>
           client.postJson(url, body)),
       _unregister = ((String url, Map<String, dynamic> body) =>
           client.deleteJson(url, body: body)),
       _baseUrl = baseUrl,
       _ensureFirebase = ensureFirebase ?? initializeFirebase,
       _persistTopics = persistTopics,
       _activeTopics = <String>{...initialTopics},
       _subscribeTopic = ((String topic) =>
           FirebaseMessaging.instance.subscribeToTopic(topic)),
       _unsubscribeTopic = ((String topic) =>
           FirebaseMessaging.instance.unsubscribeFromTopic(topic));

  /// Test seam: no Firebase, no platform channels.
  @visibleForTesting
  PushService.forTransports({
    required Future<Object?> Function(String url, Map<String, dynamic> body)
    register,
    required Future<Object?> Function(String url, Map<String, dynamic> body)
    unregister,
    required Future<String?> Function() token,
    required Future<bool> Function() requestPermission,
    Future<String> Function()? notificationStatus,
    Future<void> Function(String topic)? subscribeTopic,
    Future<void> Function(String topic)? unsubscribeTopic,
    String baseUrl = 'https://example.invalid',
    Set<String> initialTopics = const <String>{},
    Future<void> Function(Set<String>)? persistTopics,
  }) : _register = register,
       _unregister = unregister,
       _token = token,
       _requestPermission = requestPermission,
       _notificationStatus = notificationStatus,
       _subscribeTopic = subscribeTopic ?? ((String topic) async {}),
       _unsubscribeTopic = unsubscribeTopic ?? ((String topic) async {}),
       _baseUrl = baseUrl,
       _ensureFirebase = (() async => true),
       _persistTopics = persistTopics,
       _activeTopics = <String>{...initialTopics},
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
  Future<String> Function()? _notificationStatus;
  StreamSubscription<String>? _registered;
  final StreamController<Map<String, dynamic>> _taps =
      StreamController<Map<String, dynamic>>.broadcast();
  FlutterLocalNotificationsPlugin? _notifications;
  StreamSubscription<RemoteMessage>? _foreground;
  late final Future<void> Function(String topic) _subscribeTopic;
  late final Future<void> Function(String topic) _unsubscribeTopic;
  final Future<void> Function(Set<String>)? _persistTopics;
  final Set<String> _activeTopics;

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
      await _registerToken(token);
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
      await _registerToken(token);
      await _startNotifications();
    } catch (error) {
      debugPrint('PushService: ensureRegistered failed: $error');
    }
  }

  /// Registers silently when the OS permission is already granted.
  ///
  /// Covers reinstalls, restored devices and tokens rotated while the app was
  /// closed; a user who never granted permission is left for the first
  /// save/follow prompt.
  Future<void> ensureRegisteredIfGranted() async {
    try {
      if (!await _ensureFirebase()) return;
      final String status =
          await (_notificationStatus ?? _notificationStatusReal)();
      if (status != 'authorized' && status != 'provisional') return;
      await ensureRegistered();
    } catch (error) {
      debugPrint('PushService: startup registration failed: $error');
    }
  }

  /// Removes this device so it stops receiving pushes.
  Future<void> disable() async {
    await clearSegments();
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

  /// Asks only when the OS has not decided yet, then registers.
  ///
  /// Called after the first save/follow so the prompt arrives at a moment the
  /// reader understands, instead of on cold launch. A previous denial is left
  /// alone: the Settings toggle is the explicit way back in.
  Future<bool> requestIfNeeded() async {
    try {
      if (!await _ensureFirebase()) return false;
      final String status =
          await (_notificationStatus ?? _notificationStatusReal)();
      if (status == 'authorized' || status == 'provisional') {
        await ensureRegistered();
        return true;
      }
      if (status != 'notDetermined') return false;
      final bool granted =
          await (_requestPermission ?? _requestPermissionReal)();
      if (!granted) return false;
      await ensureRegistered();
      return true;
    } catch (error) {
      debugPrint('PushService: requestIfNeeded failed: $error');
      return false;
    }
  }

  /// Subscribes/unsubscribes FCM topics so delivery matches the reader's
  /// follows and notification toggles. Diff-based, so repeated calls are cheap.
  Future<void> syncSegments({
    required Set<String> followedIds,
    required AppSettings settings,
  }) async {
    final Set<String> target = segmentTopicsFor(
      followedIds: followedIds,
      settings: settings,
    );
    final Set<String> added = target.difference(_activeTopics);
    final Set<String> removed = _activeTopics.difference(target);
    for (final String topic in removed) {
      try {
        await _unsubscribeTopic.call(topic);
        _activeTopics.remove(topic);
      } catch (error) {
        debugPrint('PushService: unsubscribe $topic failed: $error');
      }
    }
    for (final String topic in added) {
      try {
        await _subscribeTopic.call(topic);
        _activeTopics.add(topic);
      } catch (error) {
        debugPrint('PushService: subscribe $topic failed: $error');
      }
    }
    await _persistActiveTopics();
  }

  /// Drops every managed topic (sign-out, notifications off).
  Future<void> clearSegments() async {
    for (final String topic in List<String>.of(_activeTopics)) {
      try {
        await _unsubscribeTopic.call(topic);
      } catch (error) {
        debugPrint('PushService: unsubscribe $topic failed: $error');
      }
    }
    _activeTopics.clear();
    await _persistActiveTopics();
  }

  /// Persists the applied set so the next launch can reconcile stale topics
  /// instead of re-subscribing to everything and forgetting removals.
  Future<void> _persistActiveTopics() async {
    final Future<void> Function(Set<String>)? persist = _persistTopics;
    if (persist == null) return;
    try {
      await persist(Set<String>.unmodifiable(_activeTopics));
    } catch (error) {
      debugPrint('PushService: persisting topics failed: $error');
    }
  }

  @visibleForTesting
  Set<String> get activeTopics => Set<String>.of(_activeTopics);

  Future<void> _registerToken(String token) async {
    await _register(_devicesUrl, <String, dynamic>{
      'token': token,
      'platform': _platform,
    });
  }

  Future<String> _notificationStatusReal() async {
    final NotificationSettings settings = await FirebaseMessaging.instance
        .getNotificationSettings();
    return settings.authorizationStatus.name;
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
    _registered ??= FirebaseMessaging.instance.onRegistered.listen((
      String token,
    ) {
      unawaited(_registerToken(token));
    });
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
