/// Timestamp parsing shared by every ingestion adapter.
///
/// Wire formats disagree — RFC-822 (`pubDate`), ISO-8601 (`published`) and Unix
/// epoch numbers all appear in the outlets SLNews aggregates — so the parsing
/// lives in one place and always yields UTC instants.
abstract final class WireDate {
  /// Parses [raw] as ISO-8601, RFC-822 or an epoch number.
  ///
  /// Returns `null` rather than throwing: a feed with a broken date must still
  /// contribute its stories, with the caller supplying a fallback timestamp.
  static DateTime? parse(String? raw) {
    final String value = raw?.trim() ?? '';
    if (value.isEmpty) return null;

    final num? epoch = num.tryParse(value);
    if (epoch != null) return fromEpoch(epoch);

    final DateTime? iso = DateTime.tryParse(value);
    if (iso != null) return iso;

    return _parseRfc822(value);
  }

  /// Converts an epoch [value] in seconds or milliseconds (auto-detected).
  static DateTime? fromEpoch(num value) {
    if (!value.isFinite) return null;
    final int raw = value.toInt();
    final bool seconds = raw.abs() < 100000000000;
    final int milliseconds = seconds ? raw * 1000 : raw;
    // Outside 1900-2100 the value is nonsense, not a date.
    if (milliseconds < -2208988800000 || milliseconds > 4102444800000) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }

  static const Map<String, int> _months = <String, int>{
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  /// Numeric zone offsets for the abbreviations feeds still emit.
  static const Map<String, int> _zones = <String, int>{
    'ut': 0,
    'utc': 0,
    'gmt': 0,
    'z': 0,
    'est': -300,
    'edt': -240,
    'cst': -360,
    'cdt': -300,
    'mst': -420,
    'mdt': -360,
    'pst': -480,
    'pdt': -420,
    'bst': 60,
    'cet': 60,
    'cest': 120,
    'eet': 120,
    'eest': 180,
    'sast': 120,
    'wat': 60,
    'cat': 120,
    'eat': 180,
  };

  static final RegExp _rfc822 = RegExp(
    r'^(?:[A-Za-z]{3,9},?\s+)?(\d{1,2})\s+([A-Za-z]{3,9})\.?\s+(\d{2,4})\s+'
    r'(\d{1,2}):(\d{2})(?::(\d{2}))?(?:\.\d+)?'
    r'(?:\s*([A-Za-z]{1,5}|[+-]\d{2}:?\d{2}))?',
  );

  /// RFC-822 / RFC-1123 dates, e.g. `Tue, 13 Oct 2026 13:30:25 +0000`.
  static DateTime? _parseRfc822(String value) {
    final Match? match = _rfc822.firstMatch(value);
    if (match == null) return null;

    final int? month = _months[match.group(2)!.toLowerCase().substring(0, 3)];
    if (month == null) return null;

    final int day = int.parse(match.group(1)!);
    int year = int.parse(match.group(3)!);
    if (year < 100) year += year < 70 ? 2000 : 1900;

    final int hour = int.parse(match.group(4)!);
    final int minute = int.parse(match.group(5)!);
    final int second = int.tryParse(match.group(6) ?? '') ?? 0;
    if (day < 1 || day > 31 || hour > 23 || minute > 59 || second > 60) {
      return null;
    }

    try {
      return DateTime.utc(
        year,
        month,
        day,
        hour,
        minute,
        second,
      ).subtract(Duration(minutes: _offsetMinutes(match.group(7))));
    } on ArgumentError {
      return null;
    }
  }

  static int _offsetMinutes(String? zone) {
    final String value = zone?.trim() ?? '';
    if (value.isEmpty) return 0;
    if (value.startsWith('+') || value.startsWith('-')) {
      final bool negative = value.startsWith('-');
      final String digits = value.substring(1).replaceAll(':', '');
      final int hours = int.tryParse(digits.substring(0, 2)) ?? 0;
      final int minutes = digits.length > 2
          ? int.tryParse(digits.substring(2, 4)) ?? 0
          : 0;
      final int total = hours * 60 + minutes;
      return negative ? -total : total;
    }
    return _zones[value.toLowerCase()] ?? 0;
  }
}
