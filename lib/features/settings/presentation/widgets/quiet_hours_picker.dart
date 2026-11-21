import 'package:flutter/material.dart';

import '../../../../core/config/l10n.dart';
import '../../../../core/domain/models/app_settings.dart';
import '../../../../core/domain/models/digest_preferences.dart';
import '../../../../core/providers/controllers.dart';

/// Quiet-hours value shown on the Settings row.
String quietHoursLabel(BuildContext context, AppSettings settings) {
  final String? start = DigestPreferences.clockLabel(settings.quietHoursStart);
  final String? end = DigestPreferences.clockLabel(settings.quietHoursEnd);
  if (start == null || end == null) return context.l10n.quietHoursOff;
  return '$start – $end';
}

/// Picks a start and end time, then persists/queues the change.
Future<void> pickQuietHours(
  BuildContext context,
  SettingsController controller,
  AppSettings settings,
) async {
  final TimeOfDay? start = await showTimePicker(
    context: context,
    initialTime: _timeOfDay(settings.quietHoursStart, fallbackHour: 22),
    helpText: context.l10n.quietHoursStart,
  );
  if (start == null || !context.mounted) return;
  final TimeOfDay? end = await showTimePicker(
    context: context,
    initialTime: _timeOfDay(settings.quietHoursEnd, fallbackHour: 7),
    helpText: context.l10n.quietHoursEnd,
  );
  if (end == null || !context.mounted) return;

  final int startMinutes = start.hour * 60 + start.minute;
  final int endMinutes = end.hour * 60 + end.minute;
  if (startMinutes == endMinutes) {
    _snack(context, context.l10n.quietHoursSameTime);
    return;
  }
  await controller.setQuietHours(start: startMinutes, end: endMinutes);
  if (context.mounted) _snack(context, context.l10n.quietHoursSaved);
}

TimeOfDay _timeOfDay(int? minutes, {required int fallbackHour}) {
  if (minutes == null || minutes < 0 || minutes >= 24 * 60) {
    return TimeOfDay(hour: fallbackHour, minute: 0);
  }
  return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
