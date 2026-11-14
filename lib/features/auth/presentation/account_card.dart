import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/auth/auth_repository.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/sync_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sl_network_image.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

/// Account entry point at the top of the Following tab.
///
/// Signed out it invites the reader to sign in (the reference app keeps a single
/// obvious account affordance); signed in it shows who is signed in, the sync
/// state of their saved stories and a sign-out. Identity itself lives behind
/// [authRepositoryProvider], so this widget contains no SDK code.
class AccountCard extends ConsumerStatefulWidget {
  const AccountCard({super.key});

  @override
  ConsumerState<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<AccountCard> {
  bool _mergeRequested = false;

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authControllerProvider);
    final SyncStatus sync = _readSyncStatus(ref);

    // First frame a reader is signed in: converge this device's local state with
    // the account's. Guarded so a rebuild cannot start a second run, and deferred
    // to a post-frame callback because it writes to providers.
    if (auth.isSignedIn && !_mergeRequested && sync is SyncIdle) {
      _mergeRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(ref.read(syncControllerProvider.notifier).mergeOnSignIn());
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Material(
        color: context.colors.surface,
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: AppSpacing.row,
          child: auth.isSignedIn
              ? _SignedInRow(user: auth.user!, sync: sync)
              : _SignedOutRow(onSignIn: () => context.push(AppRoutes.signIn)),
        ),
      ),
    );
  }
}

class _SignedInRow extends ConsumerWidget {
  const _SignedInRow({required this.user, required this.sync});

  final AuthUser user;
  final SyncStatus sync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: <Widget>[
        _Avatar(user: user),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                user.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.groupTitle.copyWith(fontSize: 17),
              ),
              Text(
                sync.label,
                maxLines: 2,
                style: context.typography.meta.copyWith(
                  color: sync is SyncFailed
                      ? context.colors.live
                      : context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        if (sync is! SyncDisabled)
          IconButton(
            tooltip: 'Sync now',
            onPressed: sync.isBusy
                ? null
                : () =>
                      ref.read(syncControllerProvider.notifier).mergeOnSignIn(),
            icon: sync.isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        TextButton(
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).signOut();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('Signed out')));
          },
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}

class _SignedOutRow extends StatelessWidget {
  const _SignedOutRow({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.colors.surfaceMuted,
          ),
          child: Icon(
            Icons.person_outline,
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Sign in',
                style: context.typography.groupTitle.copyWith(fontSize: 17),
              ),
              Text(
                'Sync saved stories and alerts with the SLNews web app',
                maxLines: 2,
                style: context.typography.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(onPressed: onSignIn, child: const Text('Sign in')),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final String? url = user.imageUrl;
    if (url != null && url.trim().isNotEmpty) {
      return SlNetworkImage(
        url: url,
        width: 44,
        height: 44,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        placeholderLabel: user.initials,
      );
    }
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colors.surfaceInverse,
      ),
      child: Text(
        user.initials,
        style: context.typography.overline.copyWith(
          color: context.colors.onSurfaceInverse,
        ),
      ),
    );
  }
}

/// Reads the sync status, tolerating a scope with no sync stack.
///
/// Feature widget tests build a bare `ProviderScope` with only the repositories
/// they exercise; there `syncRepositoryProvider` has no `ApiClient` to talk to.
/// The account card must still render (signed-out readers never see sync state
/// anyway), so a missing stack reads as "sync unavailable in this build".
SyncStatus _readSyncStatus(WidgetRef ref) {
  try {
    return ref.watch(syncControllerProvider);
  } on UnimplementedError {
    return const SyncDisabled();
  } catch (error) {
    AppLog.debug('AccountCard: sync status unavailable ($error)');
    return const SyncDisabled();
  }
}
