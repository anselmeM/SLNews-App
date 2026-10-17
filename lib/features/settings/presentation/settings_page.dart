import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/auth/auth_repository.dart';
import '../../../core/domain/models/app_settings.dart';
import '../../../core/domain/models/follow_models.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../feed/presentation/widgets/location_picker_sheet.dart';
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

  /// Mirrors `version:` in pubspec.yaml; the app has no package-info dependency.
  static const String appVersion = '1.0.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsControllerProvider);
    final AuthState auth = ref.watch(authControllerProvider);
    final SettingsController controller = ref.read(
      settingsControllerProvider.notifier,
    );
    final NewsLocation location = _activeLocation(settings.activeLocationId);

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
                      onTap: () => context.push(AppRoutes.signIn),
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
                    SettingsValueRow(
                      title: 'Manage locations',
                      value: location.label,
                      onTap: () => openLocationPicker(context, ref),
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
                    const SettingsValueRow(
                      title: 'App version',
                      value: appVersion,
                      showChevron: false,
                    ),
                    SettingsValueRow(
                      title: 'Followed location',
                      value: location.label,
                      showChevron: false,
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

  static NewsLocation _activeLocation(String id) {
    for (final NewsLocation candidate in SlLocations.all) {
      if (candidate.id == id) return candidate;
    }
    return SlLocations.all.first;
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
