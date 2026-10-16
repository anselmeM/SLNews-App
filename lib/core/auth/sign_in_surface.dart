import 'package:flutter/widgets.dart';

/// Renders the identity provider's sign-in surface.
///
/// The SDK's own widgets stay inside the data-layer adapter, so feature code
/// depends on this one-method contract instead of on Clerk. It lives in its own
/// module (rather than in `core/domain`, which is pure Dart) because it returns
/// a widget.
abstract interface class SignInSurface {
  /// Builds the provider's sign-in UI; calls [onSignedIn] once a session exists.
  Widget build(BuildContext context, {required VoidCallback onSignedIn});
}

/// A sign-in surface that explains the app is running without an identity
/// provider (used by tests and by builds without Clerk keys).
class UnavailableSignInSurface implements SignInSurface {
  const UnavailableSignInSurface({
    this.message = 'Sign-in is not configured in this build.',
  });

  final String message;

  @override
  Widget build(BuildContext context, {required VoidCallback onSignedIn}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
