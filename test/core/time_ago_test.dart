import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/utils/time_ago.dart';

void main() {
  group('TimeAgo.format', () {
    final DateTime now = DateTime(2026, 10, 15, 20, 0);

    test('collapses anything under a minute into "just now"', () {
      expect(TimeAgo.format(now.subtract(const Duration(seconds: 5)), now: now), 'just now');
      expect(TimeAgo.format(now, now: now), 'just now');
    });

    test('treats future timestamps as "just now" instead of a negative age', () {
      expect(TimeAgo.format(now.add(const Duration(hours: 3)), now: now), 'just now');
    });

    test('pluralises minutes, hours, days, weeks, months and years', () {
      expect(TimeAgo.format(now.subtract(const Duration(minutes: 1)), now: now), '1 minute ago');
      expect(TimeAgo.format(now.subtract(const Duration(minutes: 45)), now: now), '45 minutes ago');
      expect(TimeAgo.format(now.subtract(const Duration(hours: 3)), now: now), '3 hours ago');
      expect(TimeAgo.format(now.subtract(const Duration(days: 1)), now: now), '1 day ago');
      expect(TimeAgo.format(now.subtract(const Duration(days: 9)), now: now), '1 week ago');
      expect(TimeAgo.format(now.subtract(const Duration(days: 65)), now: now), '2 months ago');
      expect(TimeAgo.format(now.subtract(const Duration(days: 400)), now: now), '1 year ago');
    });

    test('short form drops the descriptive suffix', () {
      expect(TimeAgo.format(now.subtract(const Duration(minutes: 20)), now: now, short: true), '20m');
      expect(TimeAgo.format(now.subtract(const Duration(hours: 5)), now: now, short: true), '5h');
      expect(TimeAgo.format(now.subtract(const Duration(days: 3)), now: now, short: true), '3d');
    });
  });

  group('TimeAgo.absolute', () {
    test('renders the CBC-style publication line', () {
      final DateTime stamp = DateTime(2026, 10, 14, 17, 18);
      final String label = TimeAgo.absolute(stamp);
      expect(label, startsWith('Oct 14, 2026'));
      expect(label, contains('5:18 pm'));
    });

    test('appends the time zone when one is supplied', () {
      final DateTime stamp = DateTime(2026, 1, 2, 9, 5);
      expect(TimeAgo.absolute(stamp, timeZoneLabel: 'EDT'), 'Jan 2, 2026 9:05 am EDT');
    });

    test('renders midnight and noon as 12', () {
      expect(TimeAgo.absolute(DateTime(2026, 3, 1, 0, 30)), contains('12:30 am'));
      expect(TimeAgo.absolute(DateTime(2026, 3, 1, 12, 30)), contains('12:30 pm'));
    });
  });

  group('DateTimeLabels', () {
    test('labels today and yesterday by name', () {
      final DateTime today = DateTime.now();
      expect(today.shortDateLabel, 'Today');
      expect(today.subtract(const Duration(days: 1)).shortDateLabel, 'Yesterday');
    });

    test('falls back to a padded month/day label', () {
      // Relative to "now": a hard-coded date would become today/yesterday as the
      // clock moves on.
      final DateTime past = DateTime.now().subtract(const Duration(days: 400));
      final String expected =
          '${past.month.toString().padLeft(2, '0')}/${past.day.toString().padLeft(2, '0')}';
      expect(past.shortDateLabel, expected);
      expect(past.shortDateLabel, matches(RegExp(r'^\d{2}/\d{2}$')));
    });

    test('renders a clock label in 12-hour form', () {
      expect(DateTime(2026, 10, 16, 22, 30).clockLabel, '10:30PM');
      expect(DateTime(2026, 10, 16, 0, 5).clockLabel, '12:05AM');
      expect(DateTime(2026, 10, 16, 12, 0).clockLabel, '12:00PM');
    });
  });
}
