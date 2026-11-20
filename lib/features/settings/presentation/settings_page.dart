import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/legal_links.dart';
import '../../../core/data/sources/api_client.dart';
import '../../../core/domain/auth/auth_repository.dart';
import '../../../core/observability/error_reporter.dart';
import '../../../core/observability/sentry_settings.dart';
import '../../../core/domain/models/app_settings.dart';
import '../../../core/domain/models/digest_preferences.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/providers/sync_repository_provider.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'widgets/settings_card.dart';

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
    final SettingsController controller = ref.read(
      settingsControllerProvider.notifier,
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
                SettingsCard(
                  children: <Widget>[
                    SettingsValueRow(
                      title: 'SLNews account',
                      subtitle: auth.isSignedIn
                          ? (auth.user?.primaryEmail ??
                                auth.user?.label ??
                                'Signed in')
                          : 'Not signed in — tap to sign in',
                      onTap: () => context.push(
                        auth.isSignedIn ? AppRoutes.account : AppRoutes.signIn,
                      ),
                    ),
                    if (auth.isSignedIn &&
                        ref.watch(syncApiConfigProvider).isConfigured)
                      SettingsValueRow(
                        title: 'Delete account',
                        subtitle: 'Remove your account and the reading state synced for it.',
                        titleColor: context.colors.live,
                        onTap: () => _confirmAccountDeletion(context, ref),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SettingsCard(
                  header: 'Notifications',
                  children: <Widget>[
                    SettingsSwitchRow(
                      title: 'Breaking news',
                      value: settings.breakingNewsAlertsEnabled,
                      onChanged: controller.setBreakingNewsAlertsEnabled,
                    ),
                    SettingsSwitchRow(
                      title: 'Topics and newspapers',
                      subtitle:
                          'Alerts when there is a new story in a topic or from '
                          'a newspaper you follow.',
                      value: settings.followedTopicAlertsEnabled,
                      onChanged: controller.setFollowedTopicAlertsEnabled,
                    ),
                    SettingsSwitchRow(
                      title: "Editor's picks",
                      subtitle:
                          'Get top stories, daily briefings, and recommended '
                          'news.',
                      value: settings.editorsPicksEnabled,
                      onChanged: controller.setEditorsPicksEnabled,
                    ),
                    SettingsSwitchRow(
                      title: 'Interactive content',
                      subtitle:
                          'Show interactive cards such as market prices and '
                          'exchange rates.',
                      value: settings.interactiveContentEnabled,
                      onChanged: controller.setInteractiveContentEnabled,
                    ),
                    SettingsSwitchRow(
                      title: 'Sports',
                      subtitle:
                          'Get notified when teams and leagues you follow have '
                          'updates.',
                      value: settings.sportsAlertsEnabled,
                      onChanged: controller.setSportsAlertsEnabled,
                    ),
                    SettingsSwitchRow(
                      title: 'Daily digest',
                      subtitle:
                          'One summary a day of the topics and newspapers you '
                          'follow.',
                      value: settings.digestEnabled,
                      onChanged: controller.setDigestEnabled,
                    ),
                    if (settings.digestEnabled)
                      SettingsValueRow(
                        title: 'Quiet hours',
                        subtitle: 'Pause the daily digest during these hours.',
                        value: _quietHoursLabel(settings),
                        onTap: () =>
                            _pickQuietHours(context, controller, settings),
                      ),
                    if (settings.digestEnabled &&
                        settings.quietHoursStart != null &&
                        settings.quietHoursEnd != null)
                      SettingsValueRow(
                        title: 'Turn off quiet hours',
                        onTap: () async {
                          await controller.setQuietHours();
                          if (context.mounted) {
                            _showSnack(context, 'Quiet hours turned off.');
                          }
                        },
                      ),
                  ],
                ),
                const SettingsSectionLabel('News'),
                SettingsCard(
                  children: <Widget>[
                    const SettingsValueRow(
                      title: 'Language and region',
                      value: AppSettings.languageRegion,
                      showChevron: false,
                    ),
                    SettingsSwitchRow(
                      title: 'Show weather forecast',
                      value: settings.weatherForecastEnabled,
                      onChanged: controller.setWeatherForecastEnabled,
                    ),
                  ],
                ),
                const SettingsSectionLabel('Appearance'),
                SettingsCard(
                  children: <Widget>[
                    SettingsValueRow(
                      title: 'Theme',
                      value: settings.themeMode.label,
                      onTap: () => _pickTheme(context, controller, settings),
                    ),
                    SettingsValueRow(
                      title: 'Text size',
                      value: _textScaleLabel(settings.textScale),
                      onTap: () =>
                          _pickTextScale(context, controller, settings),
                    ),
                  ],
                ),
                const SettingsSectionLabel('About'),
                SettingsCard(
                  children: <Widget>[
                    SettingsValueRow(
                      title: 'Send feedback',
                      subtitle: 'Report a bug or suggest an improvement.',
                      onTap: () => _sendFeedback(context, ref),
                    ),
                    SettingsValueRow(
                      title: 'Privacy policy',
                      onTap: () => _openLegal(context, ref, LegalLinks.privacy),
                    ),
                    SettingsValueRow(
                      title: 'Terms of use',
                      onTap: () => _openLegal(context, ref, LegalLinks.terms),
                    ),
                    const SettingsValueRow(
                      title: 'App version',
                      value: appVersion,
                      showChevron: false,
                    ),
                    // Verification affordances: debug builds with reporting show
                    // them; a release build can opt in with
                    // --dart-define=SENTRY_VERIFY=true for store-pipeline checks.
                    if (_showSentryChecks &&
                        SentrySettings.fromEnvironment().isEnabled)
                      SettingsValueRow(
                        title: 'Send test event',
                        subtitle: 'Sends one message event so the Sentry project can be verified.',
                        onTap: () async {
                          await sendTestEvent();
                          if (context.mounted) {
                            _showSnack(context, 'Test event sent to Sentry.');
                          }
                        },
                      ),
                    if (_showSentryChecks &&
                        SentrySettings.fromEnvironment().isEnabled)
                      SettingsValueRow(
                        title: 'Send test exception',
                        subtitle: "Captures a deliberate exception, as Sentry's guide suggests.",
                        onTap: () async {
                          await sendTestException();
                          if (context.mounted) {
                            _showSnack(
                              context,
                              'Test exception sent to Sentry.',
                            );
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                Center(
                  child: Text(
                    'SLNews · Made for Sierra Leone',
                    style: context.typography.caption.copyWith(
                      color: context.colors.onSurfaceFaint,
                    ),
                  ),
                ),
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

  String _quietHoursLabel(AppSettings settings) {
    final String? start = DigestPreferences.clockLabel(
      settings.quietHoursStart,
    );
    final String? end = DigestPreferences.clockLabel(settings.quietHoursEnd);
    if (start == null || end == null) return 'Off';
    return '$start – $end';
  }

  Future<void> _pickQuietHours(
    BuildContext context,
    SettingsController controller,
    AppSettings settings,
  ) async {
    final TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: _timeOfDay(settings.quietHoursStart, fallbackHour: 22),
      helpText: 'Quiet hours start',
    );
    if (start == null || !context.mounted) return;
    final TimeOfDay? end = await showTimePicker(
      context: context,
      initialTime: _timeOfDay(settings.quietHoursEnd, fallbackHour: 7),
      helpText: 'Quiet hours end',
    );
    if (end == null || !context.mounted) return;

    final int startMinutes = start.hour * 60 + start.minute;
    final int endMinutes = end.hour * 60 + end.minute;
    if (startMinutes == endMinutes) {
      _showSnack(context, 'Choose different start and end times.');
      return;
    }
    await controller.setQuietHours(start: startMinutes, end: endMinutes);
    if (context.mounted) _showSnack(context, 'Quiet hours saved.');
  }

  TimeOfDay _timeOfDay(int? minutes, {required int fallbackHour}) {
    if (minutes == null || minutes < 0 || minutes >= 24 * 60) {
      return TimeOfDay(hour: fallbackHour, minute: 0);
    }
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
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
Future<void> _showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required Map<T, String> options,
  required T selected,
  required Future<void> Function(T value) onSelected,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(title, style: sheetContext.typography.groupTitle),
            ),
            for (final MapEntry<T, String> option in options.entries)
              ListTile(
                title: Text(option.value, style: sheetContext.typography.body),
                trailing: option.key == selected
                    ? Icon(
                        Icons.check,
                        color: sheetContext.colors.primary,
                        size: 20,
                      )
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onSelected(option.key);
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );
}
