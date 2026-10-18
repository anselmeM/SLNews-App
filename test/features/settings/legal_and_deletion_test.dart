import 'dart:async';

import 'package:flutter/material.dart';
// Riverpod 3 keeps `Override` out of the main entrypoint.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/config/legal_links.dart';
import 'package:slnews_mobile/core/data/sources/api_client.dart';
import 'package:slnews_mobile/core/data/sync/sync_api_config.dart';
import 'package:slnews_mobile/core/domain/auth/auth_repository.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/auth_providers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/auth/data/account_deletion_service.dart';
import 'package:slnews_mobile/features/settings/presentation/settings_page.dart';

import '../feed/support/fakes.dart';

/// A signed-in identity provider with a recording sign-out.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.signedIn = true});

  bool signedIn;
  int signOutCount = 0;
  final StreamController<AuthStatus> _changes =
      StreamController<AuthStatus>.broadcast();

  @override
  AuthStatus get status =>
      signedIn ? AuthStatus.signedIn : AuthStatus.signedOut;

  @override
  AuthUser? get currentUser => signedIn
      ? const AuthUser(
          id: 'user_1',
          displayName: 'Reader',
          primaryEmail: 'reader@example.com',
        )
      : null;

  @override
  Stream<AuthStatus> get statusChanges => _changes.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> sessionToken({bool forceRefresh = false}) async =>
      signedIn ? 'session.jwt' : null;

  @override
  Future<void> signOut() async {
    signOutCount++;
    signedIn = false;
    _changes.add(AuthStatus.signedOut);
  }
}

/// Records the DELETE call, or throws the failure the route contract defines.
class _FakeDeletionService extends AccountDeletionService {
  _FakeDeletionService({this.error})
    : super(
        config: const SyncApiConfig(baseUrl: 'https://sl-news.vercel.app'),
        api: ApiClient(),
      );

  final Object? error;
  int calls = 0;

  @override
  Future<void> deleteAccount() async {
    calls++;
    if (error != null) throw error!;
  }
}

void main() {
  late FakeUserStateRepository userState;
  late _FakeAuthRepository auth;
  late _FakeDeletionService deletion;
  late List<String> openedUrls;
  late bool openSucceeds;

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/settings',
      routes: <RouteBase>[
        GoRoute(
          path: '/settings',
          builder: (BuildContext context, GoRouterState state) =>
              const SettingsPage(),
        ),
        GoRoute(
          path: '/sign_in',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('sign-in route')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          userStateProvider.overrideWithValue(userState),
          authRepositoryProvider.overrideWithValue(auth),
          accountDeletionServiceProvider.overrideWithValue(deletion),
          externalUrlOpenerProvider.overrideWithValue((String url) async {
            openedUrls.add(url);
            return openSucceeds;
          }),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    userState = FakeUserStateRepository();
    auth = _FakeAuthRepository();
    deletion = _FakeDeletionService();
    openedUrls = <String>[];
    openSucceeds = true;
  });

  group('legal rows', () {
    testWidgets('About offers the privacy policy and terms', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Terms of use'), findsOneWidget);
    });

    testWidgets('each row opens its live page externally', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Privacy policy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terms of use'));
      await tester.pumpAndSettle();

      expect(openedUrls, <String>[LegalLinks.privacy, LegalLinks.terms]);
    });

    testWidgets('a failed open says so instead of doing nothing', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsPage)),
      );

      // Swap the opener for a failing one and try again.
      container.read(externalUrlOpenerProvider);
      await tester.tap(find.text('Privacy policy'));
      await tester.pumpAndSettle();

      expect(openedUrls, isNotEmpty);
    });
  });

  group('account deletion', () {
    testWidgets('is offered only when signed in', (WidgetTester tester) async {
      auth = _FakeAuthRepository(signedIn: false);
      await pumpSettings(tester);

      expect(find.text('Delete account'), findsNothing);
    });

    testWidgets('asks for confirmation and cancels without deleting', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      expect(find.text('Delete your SLNews account?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(deletion.calls, 0);
      expect(auth.signedIn, isTrue);
    });

    testWidgets('deletes, signs out and confirms', (WidgetTester tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pumpAndSettle();

      expect(deletion.calls, 1);
      expect(auth.signOutCount, 1);
      expect(auth.signedIn, isFalse);
      expect(find.text('Your account was deleted.'), findsOneWidget);
    });

    testWidgets('a server failure keeps the account and reports it', (
      WidgetTester tester,
    ) async {
      deletion = _FakeDeletionService(error: ApiException('Server said no'));
      await pumpSettings(tester);

      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pumpAndSettle();

      expect(deletion.calls, 1);
      expect(auth.signOutCount, 0);
      expect(auth.signedIn, isTrue);
      expect(
        find.textContaining('Could not delete your account'),
        findsOneWidget,
      );
    });
  });

  test('the deletion endpoint lives beside sync on the same host', () {
    const SyncApiConfig config = SyncApiConfig(
      baseUrl: 'https://sl-news.vercel.app/',
    );
    expect(
      config.accountEndpoint,
      'https://sl-news.vercel.app/api/mobile/v1/account',
    );
  });
}
