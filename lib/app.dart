import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/domain/auth/auth_repository.dart';
import 'core/config/l10n.dart';
import 'core/domain/models/app_settings.dart';
import 'core/providers/auth_providers.dart';
import 'core/providers/controllers.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/sync_controller.dart';
import 'l10n/app_localizations.dart';
import 'core/push/push_route.dart';
import 'core/push/push_service.dart';
import 'core/providers/app_providers.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

/// Application root: themes, router and the reader's text-size preference.
class SlNewsApp extends ConsumerWidget {
  const SlNewsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsControllerProvider);
    final GoRouter router = ref.watch(appRouterProvider);
    final Locale? locale = ref.watch(localeControllerProvider);

    // Sync is an app-level concern: a sign-in can come from Settings, the
    // Following card or a restored session, and must converge exactly once.
    ref.listen<AuthState>(authControllerProvider, (
      AuthState? previous,
      AuthState next,
    ) {
      final String? previousId = previous?.user?.id;
      final String? nextId = next.user?.id;
      final bool signingIn =
          next.isSignedIn && nextId != null && nextId != previousId;
      final bool signingOut = !next.isSignedIn && previous?.isSignedIn == true;
      if (!signingIn && !signingOut) return;

      // Provider mutations must happen after the frame that observed the auth
      // change; doing them inside this listener trips Riverpod's build guard.
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (!ref.context.mounted) return;
        if (signingIn) {
          unawaited(ref.read(syncControllerProvider.notifier).mergeOnSignIn());
        } else {
          ref.read(syncControllerProvider.notifier).onSignedOut();
        }
      });
    });

    // The identity provider wraps the app in whatever scope its SDK needs; a
    // key-less build supplies the identity function, so this costs nothing when
    // auth is not configured.
    final Widget Function(Widget child) authWrapper = ref.watch(
      authAppWrapperProvider,
    );

    return authWrapper(
      MaterialApp.router(
        title: 'SLNews',
        onGenerateTitle: (BuildContext context) => context.l10n.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: settings.themeMode.materialMode,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (BuildContext context, Widget? child) => _PushTapHandler(
          child: _TextScaleScope(
            scale: settings.textScale,
            child: child ?? const SizedBox.shrink(),
          ),
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

/// Routes notification taps to the story/video they point at.
class _PushTapHandler extends ConsumerStatefulWidget {
  const _PushTapHandler({required this.child});

  final Widget child;

  @override
  ConsumerState<_PushTapHandler> createState() => _PushTapHandlerState();
}

class _PushTapHandlerState extends ConsumerState<_PushTapHandler>
    with WidgetsBindingObserver {
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A restored signed-in session existed before this listener was installed;
    // converge it once at startup. Later auth changes go through SlNewsApp's
    // app-level listener.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;
      if (ref.read(authControllerProvider).isSignedIn) {
        unawaited(ref.read(syncControllerProvider.notifier).mergeOnSignIn());
      }
      unawaited(_refreshWeatherLocation());
    });
    try {
      final PushService push = ref.read(pushServiceProvider);
      unawaited(push.ensureRegisteredIfGranted());
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncSegments());
      _subscription = push.taps.listen((data) {
        final String? route = pushRouteFor(data);
        if (route != null && mounted) ref.read(appRouterProvider).push(route);
      });
    } catch (_) {
      // No push service in this scope.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // One failed refresh must not keep the app marked offline forever: retry
    // when the reader brings the app back to the foreground.
    unawaited(_refreshOnResume());
  }

  Future<void> _refreshOnResume() async {
    // Weather and editorial feeds are independent: do not make a fresh local
    // forecast wait for a slow news refresh.
    final Future<void> weatherRefresh = _refreshWeatherLocation();
    try {
      await ref.read(refreshFeedsProvider)();
    } catch (error) {
      AppLog.debug('PushTapHandler: resume refresh failed: $error');
    }
    await weatherRefresh;
  }

  Future<void> _refreshWeatherLocation() async {
    try {
      await ref
          .read(weatherLocationControllerProvider.notifier)
          .refreshDeviceLocation();
      // Same-place resume refreshes do not change the location selection.
      ref.invalidate(activeWeatherProvider);
    } catch (error) {
      AppLog.debug('PushTapHandler: weather location refresh failed: $error');
    }
  }

  Future<void> _syncSegments() async {
    try {
      await ref
          .read(pushServiceProvider)
          .syncSegments(
            followedIds: ref
                .read(followingControllerProvider)
                .followedIds
                .toSet(),
            settings: ref.read(settingsControllerProvider),
          );
    } catch (error) {
      AppLog.debug('PushTapHandler: segment sync failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(followingControllerProvider, (_, _) => _syncSegments());
    ref.listen(settingsControllerProvider, (_, _) => _syncSegments());
    return widget.child;
  }
}
