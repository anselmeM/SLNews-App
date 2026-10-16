import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/domain/models/app_settings.dart';
import 'core/providers/auth_providers.dart';
import 'core/providers/controllers.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

/// Application root: themes, router and the reader's text-size preference.
class SlNewsApp extends ConsumerWidget {
  const SlNewsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsControllerProvider);
    final GoRouter router = ref.watch(appRouterProvider);

    // The identity provider wraps the app in whatever scope its SDK needs; a
    // key-less build supplies the identity function, so this costs nothing when
    // auth is not configured.
    final Widget Function(Widget child) authWrapper = ref.watch(
      authAppWrapperProvider,
    );

    return authWrapper(
      MaterialApp.router(
        title: 'SLNews',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: settings.themeMode.materialMode,
        routerConfig: router,
        builder: (BuildContext context, Widget? child) => _TextScaleScope(
          scale: settings.textScale,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Applies the reader's `aA` multiplier on top of the platform text scale,
/// clamped so no layout can be pushed off-screen.
class _TextScaleScope extends StatelessWidget {
  const _TextScaleScope({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double systemScale = media.textScaler.scale(1);
    final double effective = (systemScale * scale).clamp(0.8, 2.0);
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(effective)),
      child: child,
    );
  }
}
