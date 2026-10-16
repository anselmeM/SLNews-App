import 'package:flutter/foundation.dart';

/// Session state of the reader.
enum AuthStatus {
  /// No attempt has been made yet (start-up) — the UI must not assume signed out.
  unknown,
  signedOut,
  signedIn;

  bool get isSignedIn => this == AuthStatus.signedIn;
}

/// The signed-in reader, reduced to what the UI actually shows.
@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    this.displayName,
    this.username,
    this.primaryEmail,
    this.imageUrl,
  });

  /// Provider-stable user id (`user_…` for Clerk).
  final String id;

  final String? displayName;
  final String? username;
  final String? primaryEmail;
  final String? imageUrl;

  /// Best available one-line label for the account row.
  String get label =>
      _firstNonEmpty(<String?>[displayName, username, primaryEmail]) ??
      'Signed in';

  /// Initials for the avatar fallback when no [imageUrl] is available.
  ///
  /// A profile name wins over an address; an email contributes only its local
  /// part so `kadiatu@example.com` becomes `KA`, not the domain's letters.
  String get initials {
    final String? name = _firstNonEmpty(<String?>[displayName, username]);
    final String source = name ?? (primaryEmail?.split('@').first ?? '');
    final List<String> words = source
        .split(RegExp(r'[\s._@-]+'))
        .where((String word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final String word = words.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }

  static String? _firstNonEmpty(List<String?> candidates) {
    for (final String? candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.displayName == displayName &&
      other.username == username &&
      other.primaryEmail == primaryEmail &&
      other.imageUrl == imageUrl;

  @override
  int get hashCode =>
      Object.hash(id, displayName, username, primaryEmail, imageUrl);
}

/// Immutable view of the session for widgets.
@immutable
class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.user});

  final AuthStatus status;
  final AuthUser? user;

  bool get isSignedIn => status.isSignedIn && user != null;

  static const AuthState unknown = AuthState();

  static const AuthState signedOut = AuthState(status: AuthStatus.signedOut);

  @override
  bool operator ==(Object other) =>
      other is AuthState && other.status == status && other.user == user;

  @override
  int get hashCode => Object.hash(status, user);
}

/// Identity provider contract.
///
/// Deliberately free of any SDK types: the Clerk implementation lives in the
/// data layer, so swapping or dropping a beta SDK never touches a feature.
abstract interface class AuthRepository {
  /// Current session state; [AuthStatus.unknown] until [initialize] completes.
  AuthStatus get status;

  /// The signed-in reader, or `null`.
  AuthUser? get currentUser;

  /// Emits on every session change (sign-in, token refresh, sign-out).
  Stream<AuthStatus> get statusChanges;

  /// Restores a persisted session. Must not throw; a failure means signed out.
  Future<void> initialize();

  /// Short-lived token for API calls, or `null` when signed out.
  ///
  /// [forceRefresh] requests a fresh token instead of a cached one.
  Future<String?> sessionToken({bool forceRefresh = false});

  Future<void> signOut();
}
