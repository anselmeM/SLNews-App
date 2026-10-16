import 'dart:async';

import 'package:clerk_flutter/clerk_flutter.dart' as clerk;
import 'package:flutter/widgets.dart';

import '../../auth/sign_in_surface.dart';
import '../../domain/auth/auth_repository.dart';

/// Clerk implementation of the identity contract.
///
/// This is the **only** file in the app that imports `clerk_flutter`. Everything
/// else — features, providers, the reader — talks to [AuthRepository] and
/// [SignInSurface], so the beta SDK can be replaced or removed without touching
/// a single screen. See `docs/INTEGRATIONS.md`.
///
/// The SDK's own `ClerkAuthState` is created once, here, and shared with the
/// widget tree through [wrapApp], so the session the repository reads is the
/// same session the sign-in UI writes.
class ClerkAuthRepository implements AuthRepository, SignInSurface {
  ClerkAuthRepository._(this._state) {
    _state.addListener(_emitStatus);
    _last = status;
  }

  final clerk.ClerkAuthState _state;
  final StreamController<AuthStatus> _statuses = StreamController<AuthStatus>.broadcast();
  AuthStatus _last = AuthStatus.unknown;

  /// Creates and initialises the SDK session.
  ///
  /// Throws if the publishable key is rejected or the Frontend API is
  /// unreachable; `AppBootstrap` treats that as "run without auth" rather than
  /// failing start-up.
  static Future<ClerkAuthRepository> create({required String publishableKey}) async {
    final clerk.ClerkAuthState state = await clerk.ClerkAuthState.create(
      config: clerk.ClerkAuthConfig(publishableKey: publishableKey),
    );
    return ClerkAuthRepository._(state);
  }

  /// The shared SDK session, injected into the widget tree by [wrapApp].
  clerk.ClerkAuthState get clerkAuthState => _state;

  /// Wraps the application in the SDK's inherited scope.
  Widget wrapApp(Widget child) {
    return clerk.ClerkAuth(
      authState: _state,
      child: clerk.ClerkErrorListener(child: child),
    );
  }

  @override
  AuthStatus get status => _state.isSignedIn ? AuthStatus.signedIn : AuthStatus.signedOut;

  @override
  AuthUser? get currentUser {
    // Type inferred so this file never names a `clerk_auth` model type.
    final user = _state.user;
    if (user == null) return null;
    return AuthUser(
      id: user.id,
      displayName: user.name,
      username: user.username,
      primaryEmail: user.email,
      imageUrl: user.imageUrl,
    );
  }

  @override
  Stream<AuthStatus> get statusChanges => _statuses.stream;

  /// No-op: [create] already initialised the SDK session.
  @override
  Future<void> initialize() async {}

  @override
  Future<String?> sessionToken({bool forceRefresh = false}) async {
    try {
      final token = await _state.sessionToken();
      return token.jwt;
    } catch (error) {
      debugPrint('ClerkAuthRepository: session token unavailable ($error)');
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _state.signOut();
    } catch (error) {
      debugPrint('ClerkAuthRepository: sign-out failed ($error)');
    } finally {
      _emitStatus();
    }
  }

  @override
  Widget build(BuildContext context, {required VoidCallback onSignedIn}) {
    return _ClerkSignInSurface(onSignedIn: onSignedIn);
  }

  /// Releases SDK resources; the repository lives for the app's lifetime.
  void dispose() {
    _state.removeListener(_emitStatus);
    if (!_statuses.isClosed) _statuses.close();
    _state.terminate();
  }

  void _emitStatus() {
    final AuthStatus next = status;
    if (next == _last || _statuses.isClosed) return;
    _last = next;
    _statuses.add(next);
  }
}

/// Bridges the SDK's signed-out UI to the app's sign-in route.
///
/// The SDK reports a completed sign-in through its builder, so the callback is
/// deferred to a post-frame callback rather than fired during build.
class _ClerkSignInSurface extends StatefulWidget {
  const _ClerkSignInSurface({required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  State<_ClerkSignInSurface> createState() => _ClerkSignInSurfaceState();
}

class _ClerkSignInSurfaceState extends State<_ClerkSignInSurface> {
  bool _notified = false;

  @override
  Widget build(BuildContext context) {
    return clerk.ClerkAuthBuilder(
      signedInBuilder: (context, authState) {
        if (!_notified) {
          _notified = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onSignedIn();
          });
        }
        return const SizedBox.shrink();
      },
      signedOutBuilder: (context, authState) => const clerk.ClerkAuthentication(),
    );
  }
}
