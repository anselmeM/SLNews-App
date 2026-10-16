import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/domain/auth/auth_repository.dart';
import 'package:slnews_mobile/core/providers/auth_providers.dart';
import 'package:slnews_mobile/core/routing/app_routes.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/auth/presentation/account_card.dart';
import 'package:slnews_mobile/features/auth/presentation/sign_in_page.dart';

/// Controllable identity provider: no Clerk, no network.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.status = AuthStatus.signedOut, this.currentUser});

  final StreamController<AuthStatus> _changes = StreamController<AuthStatus>.broadcast();

  @override
  AuthStatus status;

  @override
  AuthUser? currentUser;

  int initializeCalls = 0;
  int signOutCalls = 0;

  @override
  Stream<AuthStatus> get statusChanges => _changes.stream;

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  Future<String?> sessionToken({bool forceRefresh = false}) async =>
      status.isSignedIn ? 'test-session-token' : null;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    status = AuthStatus.signedOut;
    currentUser = null;
    _changes.add(status);
  }

  /// Simulates the SDK completing a sign-in.
  void completeSignIn(AuthUser user) {
    status = AuthStatus.signedIn;
    currentUser = user;
    _changes.add(status);
  }

  Future<void> dispose() => _changes.close();
}

/// Sign-in surface that stands in for the provider's own UI.
class FakeSignInSurface implements SignInSurface {
  const FakeSignInSurface();

  @override
  Widget build(BuildContext context, {required VoidCallback onSignedIn}) {
    return Center(
      child: ElevatedButton(
        key: const Key('fake-sign-in'),
        onPressed: onSignedIn,
        child: const Text('Continue with email'),
      ),
    );
  }
}

const AuthUser testUser = AuthUser(
  id: 'user_123',
  displayName: 'Aminata Kamara',
  username: 'aminata',
  primaryEmail: 'aminata@example.com',
);

void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());
  tearDown(() => repository.dispose());

  Future<void> pumpApp(WidgetTester tester, {Widget? home}) async {
    await tester.pumpWidget(
      ProviderScope(
        // Element type inferred: Riverpod 3 does not export `Override` publicly.
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          signInSurfaceProvider.overrideWithValue(const FakeSignInSurface()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: home ?? const Scaffold(body: AccountCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AccountCard', () {
    testWidgets('invites a signed-out reader to sign in', (WidgetTester tester) async {
      await pumpApp(tester);

      expect(find.text('Sign in'), findsWidgets);
      expect(find.textContaining('Sync saved stories'), findsOneWidget);
    });

    testWidgets('shows the reader and signs out', (WidgetTester tester) async {
      repository.completeSignIn(testUser);
      await pumpApp(tester);
      await tester.pumpAndSettle();

      expect(find.text('Aminata Kamara'), findsOneWidget);
      expect(find.text('AK'), findsOneWidget, reason: 'avatar falls back to initials');
      // Sync is unconfigured in this scope, so the row says so rather than
      // pretending to have synced.
      expect(find.textContaining('Sync unavailable'), findsOneWidget);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(repository.signOutCalls, 1);
      expect(find.textContaining('Sync saved stories'), findsOneWidget);
    });
  });

  group('SignInPage', () {
    testWidgets('renders the provider surface and returns once signed in', (
      WidgetTester tester,
    ) async {
      final GoRouter router = GoRouter(
        initialLocation: AppRoutes.signIn,
        routes: <RouteBase>[
          GoRoute(
            path: '/following',
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('following tab')),
          ),
          GoRoute(
            path: AppRoutes.signIn,
            builder: (BuildContext context, GoRouterState state) => const SignInPage(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(repository),
            signInSurfaceProvider.overrideWithValue(const FakeSignInSurface()),
          ],
          child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in to sync your stories'), findsOneWidget);
      expect(find.byKey(const Key('fake-sign-in')), findsOneWidget);

      // Completing sign-in inside the surface returns the reader to the tab.
      repository.completeSignIn(testUser);
      await tester.tap(find.byKey(const Key('fake-sign-in')));
      await tester.pumpAndSettle();

      expect(find.text('following tab'), findsOneWidget);
    });
  });

  group('AuthController', () {
    testWidgets('reflects provider status and a later sign-in', (WidgetTester tester) async {
      late WidgetRef captured;
      await pumpApp(
        tester,
        home: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            captured = ref;
            final AuthState auth = ref.watch(authControllerProvider);
            return Scaffold(body: Text(auth.isSignedIn ? 'in' : 'out'));
          },
        ),
      );

      expect(find.text('out'), findsOneWidget);

      await captured.read(authControllerProvider.notifier).initialize();
      expect(repository.initializeCalls, 1);

      repository.completeSignIn(testUser);
      await tester.pumpAndSettle();

      expect(find.text('in'), findsOneWidget);
      expect(captured.read(authControllerProvider).user, testUser);
    });

    testWidgets('an unconfigured build reports signed out without throwing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: AccountCard())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Sync saved stories'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AuthUser', () {
    test('derives a display label and initials from whatever is available', () {
      expect(testUser.label, 'Aminata Kamara');
      expect(testUser.initials, 'AK');
      expect(const AuthUser(id: 'u', primaryEmail: 'kadiatu@example.com').initials, 'KA');
      expect(const AuthUser(id: 'u').label, 'Signed in');
      expect(const AuthUser(id: 'u').initials, '?');
    });
  });
}
