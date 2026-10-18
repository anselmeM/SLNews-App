import 'package:flutter/foundation.dart';

/// The clock relative labels are measured against.
///
/// A seam rather than an injected dependency: [TimeAgo] is reached from plain
/// getters on models (`article.relativeAge`) that have no `Ref`, and the golden
/// renders must be able to freeze "now" or every screen with an age label drifts
/// a little further from its golden each day. Production never assigns it.
DateTime Function() appNow = () => DateTime.now();

/// Formats a [DateTime] as a short relative age ("2 hours ago").
///
/// Kept as a pure function so it is trivially unit-testable with an injected
/// `now` and usable from both widgets and tests without a BuildContext.
abstract final class TimeAgo {
  static String format(
    DateTime timestamp, {
    DateTime? now,
    bool short = false,
  }) {
    final DateTime reference = now ?? appNow();
    final Duration delta = reference.difference(timestamp);

    if (delta.inMinutes < 1) {
      return short ? 'now' : 'just now';
    }
    if (delta.inMinutes < 60) {
      final int m = delta.inMinutes;
      return short ? '${m}m' : '$m minute${m == 1 ? '' : 's'} ago';
    }
    if (delta.inHours < 24) {
      final int h = delta.inHours;
      return short ? '${h}h' : '$h hour${h == 1 ? '' : 's'} ago';
    }
    if (delta.inDays < 7) {
      final int d = delta.inDays;
      return short ? '${d}d' : '$d day${d == 1 ? '' : 's'} ago';
    }
    if (delta.inDays < 30) {
      final int w = delta.inDays ~/ 7;
      return short ? '${w}w' : '$w week${w == 1 ? '' : 's'} ago';
    }
    if (delta.inDays < 365) {
      final int mo = delta.inDays ~/ 30;
      return short ? '${mo}mo' : '$mo month${mo == 1 ? '' : 's'} ago';
    }
    final int y = delta.inDays ~/ 365;
    return short ? '${y}y' : '$y year${y == 1 ? '' : 's'} ago';
  }

  /// Abbreviation for the device's time zone, e.g. "EDT".
  ///
  /// Flutter exposes whatever the OS reports: Android/ICU say "EDT", Windows
  /// says "Eastern Daylight Time". Long names are reduced to their initials so
  /// the byline stays short everywhere, and an offset form is the fallback when
  /// the platform name is unusable.
  static String get localZoneLabel {
    final DateTime now = DateTime.now();
    return zoneLabelFor(now.timeZoneName, now.timeZoneOffset);
  }

  /// Pure form of [localZoneLabel], separated so the rules are testable without
  /// depending on the machine's zone.
  @visibleForTesting
  static String zoneLabelFor(String platformName, Duration offset) {
    final String name = platformName.trim();
    if (name.isEmpty) return _offsetLabel(offset);
    if (name.toLowerCase() == 'coordinated universal time') return 'UTC';
    if (name.length <= 5 && !name.contains(' ')) return name.toUpperCase();

    final List<String> words = name
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.length >= 2 &&
        words.every((String word) => word[0] == word[0].toUpperCase())) {
      return words.map((String word) => word[0]).join().toUpperCase();
    }
    return _offsetLabel(offset);
  }

  static String _offsetLabel(Duration offset) {
    final int hours = offset.inHours;
    final String sign = hours < 0 ? '-' : '+';
    final String hourText = hours.abs().toString().padLeft(2, '0');
    final int minutes = offset.inMinutes.abs() % 60;
    return minutes == 0
        ? 'UTC$sign$hourText'
        : 'UTC$sign$hourText:${minutes.toString().padLeft(2, '0')}';
  }

  /// Absolute label used by the article reader: "Oct 14, 2026 5:18 pm EDT".
  static String absolute(DateTime timestamp, {String? timeZoneLabel}) {
    final DateTime local = timestamp.toLocal();
    final String month = _months[local.month - 1];
    final String minute = local.minute.toString().padLeft(2, '0');
    final String period = local.hour < 12 ? 'am' : 'pm';
    final String suffix = timeZoneLabel == null ? '' : ' $timeZoneLabel';
    return '$month ${local.day}, ${local.year} ${_hour12(local.hour)}:$minute $period$suffix';
  }

  /// Publication line in the reference's wording:
  /// "Published: October 17, 2026 at 7:47 p.m. EDT".
  ///
  /// The reader spells the month out and uses dotted meridiem markers, which is
  /// what the Samsung News article header does; [absolute] stays the compact form
  /// for lists and cards.
  static String published(DateTime timestamp, {String? timeZoneLabel}) {
    final DateTime local = timestamp.toLocal();
    final String month = _monthsLong[local.month - 1];
    final String minute = local.minute.toString().padLeft(2, '0');
    final String period = local.hour < 12 ? 'a.m.' : 'p.m.';
    final String suffix = timeZoneLabel == null ? '' : ' $timeZoneLabel';
    return 'Published: $month ${local.day}, ${local.year} at '
        '${_hour12(local.hour)}:$minute $period$suffix';
  }

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _monthsLong = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String _hour12(int hour24) => '${hour24 % 12 == 0 ? 12 : hour24 % 12}';
}

/// Shared, presentation-ready date labels.
extension DateTimeLabels on DateTime {
  String get relativeLabel => TimeAgo.format(this);

  String get shortRelativeLabel => TimeAgo.format(this, short: true);

  String get absoluteLabel => TimeAgo.absolute(this);

  /// "Oct 16, 2026 7:30 pm EDT" — the compact line used by cards and lists.
  String get absoluteLabelWithZone {
    final String zone = TimeAgo.localZoneLabel;
    return TimeAgo.absolute(this, timeZoneLabel: zone.isEmpty ? null : zone);
  }

  /// "Published: October 16, 2026 at 7:30 p.m. EDT" — the reader's byline line.
  String get publishedLabelWithZone {
    final String zone = TimeAgo.localZoneLabel;
    return TimeAgo.published(this, timeZoneLabel: zone.isEmpty ? null : zone);
  }

  /// "Today" / "Yesterday" / "10/16" label used by the scoreboard headers.
  String get shortDateLabel {
    final DateTime now = appNow();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime self = DateTime(year, month, day);
    final int diff = today.difference(self).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}';
  }

  /// "10:30PM" label used by the scoreboard tip-off column.
  String get clockLabel {
    final int h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${minute.toString().padLeft(2, '0')}${hour < 12 ? 'AM' : 'PM'}';
  }
}
