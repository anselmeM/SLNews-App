import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/config/legal_links.dart';
import 'package:slnews_mobile/core/domain/auth/auth_repository.dart';
import 'package:slnews_mobile/core/providers/auth_providers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/auth/presentation/account_page.dart';

class _FakeAuth implements AuthRepository {
  _FakeAuth({this.signedIn = true});
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
          id: 'u1',
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
      signedIn ? 't' : null;
  @override
  Future<void> signOut() async {
    signOutCount++;
    signedIn = false;
  }
}

void main() {
  Future<void> pumpAccount(WidgetTester tester, _FakeAuth auth) async {
    final GoRouter router = GoRouter(
      initialLocation: '/account',
      routes: <RouteBase>[
        GoRoute(path: '/account', builder: (_, __) => const AccountPage()),
        GoRoute(
          path: '/sign_in',
          builder: (_, __) => const Scaffold(body: Text('sign-in')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(auth),
          externalUrlOpenerProvider.overrideWithValue((String _) async => true),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('signed in: shows identity, sign out and delete', (
    WidgetTester tester,
  ) async {
    await pumpAccount(tester, _FakeAuth());
    expect(find.text('Reader'), findsOneWidget);
    expect(find.text('reader@example.com'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets('signed out: explains the account and offers sign in', (
    WidgetTester tester,
  ) async {
    await pumpAccount(tester, _FakeAuth(signedIn: false));
    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Delete account'), findsNothing);
  });

  testWidgets('sign out calls the repository', (WidgetTester tester) async {
    final _FakeAuth auth = _FakeAuth();
    await pumpAccount(tester, auth);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(auth.signOutCount, 1);
  });
}
