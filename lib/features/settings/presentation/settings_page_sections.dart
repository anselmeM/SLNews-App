part of 'settings_page.dart';

extension _SettingsSections on SettingsPage {
  Widget _accountCard(BuildContext context, WidgetRef ref, AuthState auth) {
    return SettingsCard(
      children: <Widget>[
        SettingsValueRow(
          title: 'SLNews account',
          subtitle: auth.isSignedIn
              ? (auth.user?.primaryEmail ?? auth.user?.label ?? 'Signed in')
              : 'Not signed in — tap to sign in',
          onTap: () => context.push(
            auth.isSignedIn ? AppRoutes.account : AppRoutes.signIn,
          ),
        ),
        if (auth.isSignedIn && ref.watch(syncApiConfigProvider).isConfigured)
          SettingsValueRow(
            title: 'Delete account',
            subtitle:
                'Remove your account and the reading state synced for it.',
            titleColor: context.colors.live,
            onTap: () => _confirmAccountDeletion(context, ref),
          ),
      ],
    );
  }

  Widget _notificationsCard(
    BuildContext context,
    SettingsController controller,
    AppSettings settings,
  ) {
    final l10n = context.l10n;
    return SettingsCard(
      header: l10n.settingsNotifications,
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
          title: l10n.dailyDigest,
          subtitle: l10n.dailyDigestSubtitle,
          value: settings.digestEnabled,
          onChanged: controller.setDigestEnabled,
        ),
        if (settings.digestEnabled)
          SettingsValueRow(
            title: l10n.quietHours,
            subtitle: l10n.quietHoursSubtitle,
            value: quietHoursLabel(context, settings),
            onTap: () => pickQuietHours(context, controller, settings),
          ),
        if (settings.digestEnabled &&
            settings.quietHoursStart != null &&
            settings.quietHoursEnd != null)
          SettingsValueRow(
            title: l10n.turnOffQuietHours,
            onTap: () async {
              await controller.setQuietHours();
              if (context.mounted) {
                _showSnack(context, 'Quiet hours turned off.');
              }
            },
          ),
      ],
    );
  }

  Widget _newsCard(
    BuildContext context,
    WidgetRef ref,
    SettingsController controller,
    AppSettings settings,
    PersonalizationProfile personalizationProfile,
    int aggregateDiagnosticCount,
    WeatherLocationState weatherLocation,
    AppLanguage selectedLanguage,
  ) {
    final l10n = context.l10n;
    return SettingsCard(
      children: <Widget>[
        SettingsValueRow(
          title: l10n.languageAndRegion,
          value: selectedLanguage.endonym,
          onTap: () => pickAppLanguage(context, ref),
        ),
        SettingsSwitchRow(
          title: 'Show weather forecast',
          value: settings.weatherForecastEnabled,
          onChanged: controller.setWeatherForecastEnabled,
        ),
        SettingsSwitchRow(
          title: 'Personalize For You',
          subtitle:
              'Use follows, saves and reading history to shape the '
              'home feed. Your choices stay on this device.',
          value: settings.personalizeFeed,
          onChanged: controller.setPersonalizeFeed,
        ),
        SettingsValueRow(
          title: 'Personalization data',
          subtitle: personalizationProfile.isEmpty
              ? 'No on-device activity yet'
              : 'Signals and reading positions stay on this phone',
          value: personalizationProfile.isEmpty
              ? 'None'
              : '${personalizationProfile.eventCount} signals',
          onTap: () =>
              _showPersonalizationData(context, personalizationProfile, ref),
        ),
        SettingsSwitchRow(
          title: 'Anonymous diagnostics',
          subtitle:
              'Allow aggregate usage counts that help improve '
              'rankings. No account details or reading history. '
              'Off by default.',
          value: settings.analyticsEnabled,
          onChanged: controller.setAnalyticsEnabled,
        ),
        SettingsValueRow(
          title: 'Anonymous diagnostics data',
          subtitle: 'Stored on this phone. Nothing is uploaded yet.',
          value: aggregateDiagnosticCount == 0
              ? 'None'
              : '$aggregateDiagnosticCount counters',
        ),
        SettingsValueRow(
          title: 'Weather location',
          subtitle: weatherLocation.usingDevice
              ? 'Using approximate current location'
              : 'Using the saved news location',
          value: weatherLocation.location.label,
          onTap: () => showWeatherLocationSheet(context),
        ),
      ],
    );
  }

  Widget _appearanceCard(
    BuildContext context,
    SettingsController controller,
    AppSettings settings,
  ) {
    return SettingsCard(
      children: <Widget>[
        SettingsValueRow(
          title: 'Theme',
          value: settings.themeMode.label,
          onTap: () => _pickTheme(context, controller, settings),
        ),
        SettingsValueRow(
          title: 'Text size',
          value: SettingsPage._textScaleLabel(settings.textScale),
          onTap: () => _pickTextScale(context, controller, settings),
        ),
      ],
    );
  }

  Widget _aboutCard(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsCard(
          children: <Widget>[
            SettingsValueRow(
              title: l10n.sendFeedback,
              subtitle: l10n.feedbackSubtitle,
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
              value: SettingsPage.appVersion,
              showChevron: false,
            ),
            // Verification affordances: debug builds with reporting show
            // them; a release build can opt in with
            // --dart-define=SENTRY_VERIFY=true for store-pipeline checks.
            if (SettingsPage._showSentryChecks &&
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
            if (SettingsPage._showSentryChecks &&
                SentrySettings.fromEnvironment().isEnabled)
              SettingsValueRow(
                title: 'Send test exception',
                subtitle: "Captures a deliberate exception, as Sentry's guide suggests.",
                onTap: () async {
                  await sendTestException();
                  if (context.mounted) {
                    _showSnack(context, 'Test exception sent to Sentry.');
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
    );
  }
}
