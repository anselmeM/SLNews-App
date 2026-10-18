import '../../../core/data/sources/api_client.dart';
import '../../../core/data/sync/sync_api_config.dart';

/// Deletes the signed-in reader's account on the SLNews backend.
///
/// Thin on purpose: the endpoint owns the semantics (rows first, then the Clerk
/// identity). The app only has to surface the contract — a 200 means the account
/// and its synced data are gone; anything else is an [ApiException] the caller
/// must show, because a silent failure would leave the reader believing an
/// irreversible action happened when it did not.
class AccountDeletionService {
  AccountDeletionService({required this.config, required this._api});

  final SyncApiConfig config;
  final ApiClient _api;

  /// Deletion needs a backend to delete from.
  bool get isAvailable => config.isConfigured;

  Future<void> deleteAccount() async {
    if (!isAvailable) {
      throw ApiException('Account deletion is not available in this build.');
    }
    await _api.deleteJson(config.accountEndpoint);
  }
}
