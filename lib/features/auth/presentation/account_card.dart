import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/auth/auth_repository.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sl_network_image.dart';

/// Account entry point at the top of the Following tab.
///
/// Signed out it invites the reader to sign in (the reference app keeps a single
/// obvious account affordance); signed in it shows who is signed in and offers
/// sign-out. Identity itself lives behind [authRepositoryProvider], so this
/// widget contains no SDK code.
class AccountCard extends ConsumerWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState auth = ref.watch(authControllerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: Material(
        color: context.colors.surface,
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: AppSpacing.row,
          child: auth.isSignedIn
              ? _SignedInRow(user: auth.user!)
              : _SignedOutRow(
                  onSignIn: () => context.push(AppRoutes.signIn),
                ),
        ),
      ),
    );
  }
}

class _SignedInRow extends ConsumerWidget {
  const _SignedInRow({required this.user});

  final AuthUser user;

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
              if (user.primaryEmail != null)
                Text(
                  user.primaryEmail!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.meta,
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
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
          child: Icon(Icons.person_outline, color: context.colors.onSurfaceVariant),
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
                'Sync saved stories and alerts with slnews.sl',
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
      decoration: BoxDecoration(shape: BoxShape.circle, color: context.colors.surfaceInverse),
      child: Text(
        user.initials,
        style: context.typography.overline.copyWith(color: context.colors.onSurfaceInverse),
      ),
    );
  }
}
