/// Formats a [DateTime] as a short relative age ("2 hours ago").
///
/// Kept as a pure function so it is trivially unit-testable with an injected
/// `now` and usable from both widgets and tests without a BuildContext.
abstract final class TimeAgo {
  static String format(DateTime timestamp, {DateTime? now, bool short = false}) {
    final DateTime reference = now ?? DateTime.now();
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

  /// Absolute label used by the article reader: "Oct 14, 2026 5:18 pm EDT".
  static String absolute(DateTime timestamp, {String? timeZoneLabel}) {
    final DateTime local = timestamp.toLocal();
    final String month = _months[local.month - 1];
    final String minute = local.minute.toString().padLeft(2, '0');
    final String period = local.hour < 12 ? 'am' : 'pm';
    final String suffix = timeZoneLabel == null ? '' : ' $timeZoneLabel';
    return '$month ${local.day}, ${local.year} ${_hour12(local.hour)}:$minute $period$suffix';
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

  static String _hour12(int hour24) => '${hour24 % 12 == 0 ? 12 : hour24 % 12}';
}

/// Shared, presentation-ready date labels.
extension DateTimeLabels on DateTime {
  String get relativeLabel => TimeAgo.format(this);

  String get shortRelativeLabel => TimeAgo.format(this, short: true);

  String get absoluteLabel => TimeAgo.absolute(this);

  /// "Today" / "Yesterday" / "10/16" label used by the scoreboard headers.
  String get shortDateLabel {
    final DateTime now = DateTime.now();
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
