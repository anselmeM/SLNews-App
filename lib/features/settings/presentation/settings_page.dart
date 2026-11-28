import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_language.dart';
import '../../../core/config/l10n.dart';
import '../../../core/config/legal_links.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/data/sources/api_client.dart';
import '../../../core/domain/auth/auth_repository.dart';
import '../../../core/observability/error_reporter.dart';
import '../../../core/observability/sentry_settings.dart';
import '../../../core/domain/models/app_settings.dart';
import '../../../core/domain/models/personalization_profile.dart';
import '../../../core/domain/models/weather_location_state.dart';
import '../../../core/providers/aggregate_metrics.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/providers/personalization_profile.dart';
import '../../../core/providers/sync_repository_provider.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../feed/presentation/widgets/weather_location_sheet.dart';
import 'widgets/language_picker.dart';
import 'widgets/quiet_hours_picker.dart';
import 'widgets/settings_card.dart';

part 'settings_page_sections.dart';
part 'settings_page_sheets.dart';

/// Reader settings, reconstructed from the reference "News settings" screen.
///
/// One card per group: the account, notification categories, news presentation
/// and — because the app already persists them and had no screen to change them
/// — appearance (theme, text size) plus an about block.
///
/// Every switch writes through [SettingsController], so the change is persisted
/// immediately, applies to the running app, and survives a restart.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  /// The About verification actions appear in debug builds, or in a release build
  /// explicitly compiled with `--dart-define=SENTRY_VERIFY=true` for a store-pipeline
  /// check. Reporting still has to be configured and enabled on top of that.
  static const bool _showSentryChecks =
      kDebugMode || bool.fromEnvironment('SENTRY_VERIFY');

  /// Mirrors `version:` in pubspec.yaml; the app has no package-info dependency.
  static const String appVersion = '1.0.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsControllerProvider);
    final AuthState auth = ref.watch(authControllerProvider);
    final WeatherLocationState weatherLocation = ref.watch(
      weatherLocationControllerProvider,
    );
    final PersonalizationProfile personalizationProfile = ref.watch(
      personalizationProfileProvider,
    );
    final int aggregateDiagnosticCount = ref
        .watch(aggregateMetricsProvider)
        .totalCount;
    final SettingsController controller = ref.read(
      settingsControllerProvider.notifier,
    );
    final l10n = context.l10n;
    final AppLanguage selectedLanguage = AppLanguage.fromLocale(
      ref.watch(localeControllerProvider),
    );

    return Scaffold(
      backgroundColor: context.colors.canvas,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: context.colors.canvas,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () => context.pop(),
            ),
            title: Text(
              'SLNews settings',
              style: context.typography.groupTitle.copyWith(fontSize: 22),
            ),
            centerTitle: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                _accountCard(context, ref, auth),
                const SizedBox(height: AppSpacing.md),
                _notificationsCard(context, controller, settings),
                SettingsSectionLabel(l10n.settingsNews),
                _newsCard(
                  context,
                  ref,
                  controller,
                  settings,
                  personalizationProfile,
                  aggregateDiagnosticCount,
                  weatherLocation,
                  selectedLanguage,
                ),
                SettingsSectionLabel(l10n.settingsAppearance),
                _appearanceCard(context, controller, settings),
                SettingsSectionLabel(l10n.settingsAbout),
                _aboutCard(context, ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLegal(
    BuildContext context,
    WidgetRef ref,
    String url,
  ) async {
    final bool opened = await ref.read(externalUrlOpenerProvider)(url);
    if (!opened && context.mounted) {
      _showSnack(context, 'Could not open the link.');
    }
  }

  /// Confirms, deletes server-side, then signs out.
  ///
  /// The confirmation is a dialog rather than a switch because the action is
  /// irreversible; the failure path keeps the account and says so, so the reader
  /// never believes data was deleted when the server refused.
  Future<void> _confirmAccountDeletion(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete your SLNews account?'),
        content: const Text(
          'This removes your account and the saved stories, likes and follows '
          'synced for it. It cannot be undone. Content cached on this phone '
          'stays until you clear the app data or uninstall it.',
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
      if (context.mounted) _showSnack(context, 'Your account was deleted.');
    } on ApiException catch (error) {
      if (context.mounted) {
        _showSnack(context, 'Could not delete your account. ${error.message}');
      }
    } catch (error) {
      // Any other failure must still keep the account and tell the reader.
      if (context.mounted) {
        _showSnack(
          context,
          'Could not delete your account. Please try again or contact support.',
        );
      }
    }
  }

  void _sendFeedback(BuildContext context, WidgetRef ref) {
    final String device =
        '${defaultTargetPlatform.name} · ${Platform.operatingSystemVersion}';
    final Uri uri = Uri(
      scheme: 'mailto',
      path: LegalLinks.supportEmail,
      queryParameters: <String, String>{
        'subject': 'SLNews feedback ($appVersion)',
        'body': '\n\n---\nApp: $appVersion\nDevice: $device\n',
      },
    );
    ref.read(externalUrlOpenerProvider)(uri.toString());
    _showSnack(context, 'Opening your mail app…');
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static String _textScaleLabel(double scale) {
    final int percent = (scale * 100).round();
    return percent == 100 ? 'Default (100%)' : '$percent%';
  }

  Future<void> _pickTheme(
    BuildContext context,
    SettingsController controller,
    AppSettings settings,
  ) async {
    await _showChoiceSheet<AppThemeMode>(
      context,
      title: 'Theme',
      options: <AppThemeMode, String>{
        for (final AppThemeMode mode in AppThemeMode.values) mode: mode.label,
      },
      selected: settings.themeMode,
      onSelected: controller.setThemeMode,
    );
  }

  Future<void> _pickTextScale(
    BuildContext context,
    SettingsController controller,
    AppSettings settings,
  ) async {
    await _showChoiceSheet<double>(
      context,
      title: 'Text size',
      options: <double, String>{
        for (final double scale in AppSettings.textScaleSteps)
          scale: _textScaleLabel(scale),
      },
      selected: settings.textScale,
      onSelected: controller.setTextScale,
    );
  }
}

/// Bottom sheet of mutually exclusive options, used for theme and text size.
