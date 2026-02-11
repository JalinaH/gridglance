import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/utils/date_time_format.dart';

void main() {
  test('formatLastUpdatedAgo returns human-friendly relative labels', () {
    final now = DateTime(2026, 2, 11, 12, 0, 0);

    expect(
      formatLastUpdatedAgo(now.subtract(Duration(seconds: 40)), now: now),
      'Last updated just now',
    );
    expect(
      formatLastUpdatedAgo(now.subtract(Duration(minutes: 1)), now: now),
      'Last updated 1 min ago',
    );
    expect(
      formatLastUpdatedAgo(now.subtract(Duration(minutes: 42)), now: now),
      'Last updated 42 mins ago',
    );
    expect(
      formatLastUpdatedAgo(now.subtract(Duration(hours: 3)), now: now),
      'Last updated 3 hours ago',
    );
    expect(
      formatLastUpdatedAgo(now.subtract(Duration(days: 2)), now: now),
      'Last updated 2 days ago',
    );
  });

  testWidgets('formatLocalDate matches MaterialLocalizations short date', (
    tester,
  ) async {
    late String actual;
    late String expected;
    final dateTime = DateTime.utc(2026, 3, 8, 14, 5);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            actual = formatLocalDate(context, dateTime);
            expected = MaterialLocalizations.of(
              context,
            ).formatShortDate(dateTime.toLocal());
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(actual, expected);
  });

  testWidgets(
    'formatLocalDateTime returns short date + 12-hour time with hyphen',
    (tester) async {
      late String actual;
      late String expected;
      final dateTime = DateTime.utc(2026, 11, 21, 18, 45);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final local = dateTime.toLocal();
              final localizations = MaterialLocalizations.of(context);
              actual = formatLocalDateTime(context, dateTime);
              expected =
                  '${localizations.formatShortDate(local)} - '
                  '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: false)}';
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(actual, expected);
    },
  );
}
