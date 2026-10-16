import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/sign_in_surface.dart';
import '../domain/auth/auth_repository.dart';

export '../auth/sign_in_surface.dart';

/// Identity wiring.
///
/// Everything here is optional: when no provider is configured the app runs
/// exactly as before (anonymous, device-local), and [authControllerProvider]
/// simply reports [AuthStatus.signedOut].

/// The configured identity provider.
///
/// Defaults to an unconfigured stand-in so a test or a key-less build can pump
/// the app without an auth stack; `AppBootstrap` replaces it with Clerk's
/// adapter when a publishable key is present.
final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>(
  (Ref ref) => const UnconfiguredAuthRepository(),
  name: 'authRepository',
);

final Provider<SignInSurface> signInSurfaceProvider = Provider<SignInSurface>(
  (Ref ref) => const UnavailableSignInSurface(),
  name: 'signInSurface',
);

/// Wraps the whole app in whatever scope the identity provider needs.
///
/// Keeping this as a function means `app.dart` never imports an auth SDK: the
/// Clerk adapter supplies `(child) => ClerkAuth(authState: …, child: child)` and
/// a key-less build supplies the identity function.
final Provider<Widget Function(Widget child)> authAppWrapperProvider =
    Provider<Widget Function(Widget child)>((Ref ref) => (Widget child) => child, name: 'authAppWrapper');

/// Session state for widgets.
final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new, name: 'authController');

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final AuthRepository repository = ref.watch(authRepositoryProvider);
    final StreamSubscription<AuthStatus> subscription = repository.statusChanges.listen((
      AuthStatus _,
    ) {
      state = AuthState(status: repository.status, user: repository.currentUser);
    });
    ref.onDispose(subscription.cancel);
    return AuthState(status: repository.status, user: repository.currentUser);
  }

  /// Restores a persisted session; safe to call more than once.
  Future<void> initialize() async {
    final AuthRepository repository = ref.read(authRepositoryProvider);
    await repository.initialize();
    state = AuthState(status: repository.status, user: repository.currentUser);
  }

  Future<void> signOut() async {
    final AuthRepository repository = ref.read(authRepositoryProvider);
    await repository.signOut();
    state = AuthState(status: repository.status, user: repository.currentUser);
  }
}

/// Stand-in used when the build has no identity provider configured.
class UnconfiguredAuthRepository implements AuthRepository {
  const UnconfiguredAuthRepository();

  @override
  AuthStatus get status => AuthStatus.signedOut;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthStatus> get statusChanges => const Stream<AuthStatus>.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> sessionToken({bool forceRefresh = false}) async => null;

  @override
  Future<void> signOut() async {}
}
