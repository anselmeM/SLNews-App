import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';

import 'package:go_router/go_router.dart';

import '../../../core/config/legal_links.dart';
import '../../../core/data/sources/api_client.dart';
import '../../../core/domain/auth/auth_repository.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// The reader's account screen (`/account`): identity, sign-out and deletion.
///
/// Sign-in stays optional everywhere else in the app; this is the one place that
/// spells out what the account holds and how to remove it.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState auth = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        backgroundColor: context.colors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: Text('SLNews account', style: context.typography.groupTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          if (!auth.isSignedIn) ...<Widget>[
            const SizedBox(height: AppSpacing.xxl),
            Icon(
              Icons.account_circle_outlined,
              size: 56,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Not signed in',
              textAlign: TextAlign.center,
              style: context.typography.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Signing in keeps your saved stories, likes and follows on every device. '
              'Reading, search and saving all work without an account.',
              textAlign: TextAlign.center,
              style: context.typography.body.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => context.push(AppRoutes.signIn),
              child: const Text('Sign in'),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ] else ...<Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 28,
                  backgroundColor: context.colors.surfaceInverse,
                  child: Text(
                    auth.user?.initials ?? '?',
                    style: context.typography.groupTitle.copyWith(
                      color: context.colors.onSurfaceInverse,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        auth.user?.label ?? 'Signed in',
                        style: context.typography.groupTitle,
                      ),
                      if (auth.user?.primaryEmail != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          auth.user!.primaryEmail!,
                          style: context.typography.caption.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _AccountRow(
              label: 'Sign out',
              icon: Icons.logout,
              onTap: () async {
                await ref.read(authControllerProvider.notifier).signOut();
                try {
                  await ref.read(pushServiceProvider).disable();
                } catch (_) {
                  // Push not wired in this build.
                }
                if (context.mounted && context.canPop()) context.pop();
              },
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _AccountRow(
            label: 'Privacy policy',
            icon: Icons.privacy_tip_outlined,
            onTap: () =>
                ref.read(externalUrlOpenerProvider)(LegalLinks.privacy),
          ),
          _AccountRow(
            label: 'Terms of use',
            icon: Icons.description_outlined,
            onTap: () => ref.read(externalUrlOpenerProvider)(LegalLinks.terms),
          ),
          if (auth.isSignedIn)
            _AccountRow(
              label: 'Delete account',
              icon: Icons.delete_forever_outlined,
              destructive: true,
              onTap: () => _confirmDeletion(context, ref),
            ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Deleting your account removes the saved stories, likes and follows synced '
            'for it. Stories cached on this phone stay until the app data is cleared.',
            style: context.typography.caption.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletion(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete your SLNews account?'),
        content: const Text(
          'This removes your account and the data synced for it. It cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: dialogContext.colors.live,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(accountDeletionServiceProvider).deleteAccount();
      await ref.read(authControllerProvider.notifier).signOut();
      try {
        await ref.read(pushServiceProvider).disable();
      } catch (_) {
        // Push not wired in this build.
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account was deleted.')),
      );
      if (context.canPop()) context.pop();
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete your account. ${error.message}'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not delete your account. Please try again or contact support.',
            ),
          ),
        );
      }
    }
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color colour = destructive
        ? context.colors.live
        : context.colors.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: context.colors.surface,
        borderRadius: AppRadius.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: AppSpacing.row,
            child: Row(
              children: <Widget>[
                Icon(icon, size: 20, color: colour),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: context.typography.body.copyWith(color: colour),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: context.colors.onSurfaceFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
