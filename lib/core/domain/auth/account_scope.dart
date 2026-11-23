/// Identity boundary for reader-owned local state.
///
/// Signed-out readers get their own `anonymous` namespace. A Clerk account gets
/// a namespace derived from its immutable user id, so switching accounts never
/// exposes or merges another reader's saved stories, likes or follows.
library;

/// Stable key used when no reader is signed in.
const String anonymousAccountId = 'anonymous';

/// Normalises an auth user id into a local-storage account key.
String localAccountIdFor(String? userId) {
  final String trimmed = userId?.trim() ?? '';
  return trimmed.isEmpty ? anonymousAccountId : trimmed;
}
