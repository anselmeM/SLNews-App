import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/models/follow_models.dart';
import '../../../../core/domain/models/weather_location_state.dart';
import '../../../../core/location/device_location_service.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Lets the reader choose between the device's approximate location and the
/// saved news location. Permission is requested only after the explicit
/// "Use my location" action.
Future<void> showWeatherLocationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => const _WeatherLocationSheet(),
  );
}

class _WeatherLocationSheet extends ConsumerWidget {
  const _WeatherLocationSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WeatherLocationState state = ref.watch(
      weatherLocationControllerProvider,
    );
    final NewsLocation fallback = ref.watch(activeLocationProvider);
    final WeatherLocationController controller = ref.read(
      weatherLocationControllerProvider.notifier,
    );
    final DeviceLocationStatus? status = state.status;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Weather location',
              style: context.typography.groupTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Used only for the weather card. Your news feed stays '
              'Sierra Leone-first.',
              style: context.typography.caption.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.my_location),
              title: const Text('Use my location'),
              subtitle: Text(
                state.usingDevice
                    ? 'Current: ${state.location.label}'
                    : 'Uses approximate, rounded location',
              ),
              trailing: state.busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : state.usingDevice
                  ? Icon(Icons.check, color: context.colors.primary)
                  : null,
              onTap: state.busy
                  ? null
                  : () async {
                      final DeviceLocationStatus result = await controller
                          .useCurrentLocation();
                      if (!context.mounted) return;
                      if (result == DeviceLocationStatus.granted) {
                        Navigator.of(context).pop();
                      } else {
                        _showStatus(context, result);
                      }
                    },
            ),
            if (status == DeviceLocationStatus.deniedForever)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => controller.openSystemSettings(),
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Open app settings'),
                ),
              ),
            const Divider(height: AppSpacing.xl),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined),
              title: Text('Use ${fallback.label}'),
              subtitle: const Text('Saved news location'),
              trailing: !state.usingDevice
                  ? Icon(Icons.check, color: context.colors.primary)
                  : null,
              onTap: state.busy
                  ? null
                  : () async {
                      await controller.useNewsLocation();
                      if (context.mounted) Navigator.of(context).pop();
                    },
            ),
            if (status != null && status != DeviceLocationStatus.granted)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  _statusText(status),
                  style: context.typography.caption.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Approximate location is rounded before it is sent to the '
              'weather service and your device\'s platform geocoder, which '
              'resolves the place name. It is never used for advertising.',
              style: context.typography.caption.copyWith(
                color: context.colors.onSurfaceFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusText(DeviceLocationStatus status) => switch (status) {
    DeviceLocationStatus.denied => 'Location permission was denied. You can retry or allow it in Android settings.',
    DeviceLocationStatus.deniedForever => 'Location permission is turned off for SLNews. Open app settings to allow it.',
    DeviceLocationStatus.servicesDisabled =>
      'Location services are turned off on this device.',
    DeviceLocationStatus.unavailable =>
      'Your current location could not be determined right now.',
    DeviceLocationStatus.granted => '',
  };

  static void _showStatus(BuildContext context, DeviceLocationStatus status) {
    final String message = _statusText(status);
    if (message.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
