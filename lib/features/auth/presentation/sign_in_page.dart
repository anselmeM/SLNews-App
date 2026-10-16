import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Sign-in screen (`/sign_in`).
///
/// The provider's own widgets are supplied by [signInSurfaceProvider], so this
/// page — and every feature — stays free of SDK types. The reader lands back on
/// the previous screen as soon as a session exists.
class SignInPage extends ConsumerWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SignInSurface surface = ref.watch(signInSurfaceProvider);

    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        backgroundColor: context.colors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('SLNews', style: context.typography.groupTitle),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/following');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Sign in to sync your stories',
                    style: context.typography.sectionTitle,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Saved stories, reactions and alerts follow you between this app and the SLNews web app.',
                    style: context.typography.caption,
                  ),
                ],
              ),
            ),
            Expanded(
              child: surface.build(
                context,
                onSignedIn: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/following');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
