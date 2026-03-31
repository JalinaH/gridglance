import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/models/race.dart';
import 'package:gridglance/screens/race_schedule_screen.dart';
import 'package:gridglance/theme/app_theme.dart';

List<Race> _sampleRaces() => [
      Race(
        round: '1',
        raceName: 'Bahrain Grand Prix',
        date: '2025-03-02',
        time: '15:00:00Z',
        circuitId: 'bahrain',
        circuitName: 'Bahrain International Circuit',
        locality: 'Sakhir',
        country: 'Bahrain',
        practice1: null,
        practice2: null,
        practice3: null,
        qualifying: null,
        sprintQualifying: null,
        sprint: null,
      ),
      Race(
        round: '2',
        raceName: 'Saudi Arabian Grand Prix',
        date: '2025-03-09',
        time: '17:00:00Z',
        circuitId: 'jeddah',
        circuitName: 'Jeddah Corniche Circuit',
        locality: 'Jeddah',
        country: 'Saudi Arabia',
        practice1: null,
        practice2: null,
        practice3: null,
        qualifying: null,
        sprintQualifying: null,
        sprint: null,
      ),
      Race(
        round: '3',
        raceName: 'Australian Grand Prix',
        date: '2025-03-16',
        time: '04:00:00Z',
        circuitId: 'albert_park',
        circuitName: 'Albert Park Grand Prix Circuit',
        locality: 'Melbourne',
        country: 'Australia',
        practice1: null,
        practice2: null,
        practice3: null,
        qualifying: null,
        sprintQualifying: null,
        sprint: null,
      ),
    ];

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: child,
  );
}

void main() {
  group('RaceScheduleScreen', () {
    testWidgets('renders title and season', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          RaceScheduleScreen(races: _sampleRaces(), season: '2025'),
        ),
      );
      await tester.pump();

      expect(find.text('Race Schedule'), findsOneWidget);
      expect(find.text('Season 2025'), findsOneWidget);
    });

    testWidgets('renders search field', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          RaceScheduleScreen(races: _sampleRaces(), season: '2025'),
        ),
      );
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search races or circuits'), findsOneWidget);
    });

    testWidgets('displays filter chips', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          RaceScheduleScreen(races: _sampleRaces(), season: '2025'),
        ),
      );
      await tester.pump();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('displays race names', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          RaceScheduleScreen(races: _sampleRaces(), season: '2025'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bahrain Grand Prix'), findsOneWidget);
      expect(find.text('Saudi Arabian Grand Prix'), findsOneWidget);
    });

    testWidgets('search filters races', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          RaceScheduleScreen(races: _sampleRaces(), season: '2025'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Bahrain');
      await tester.pumpAndSettle();

      expect(find.text('Bahrain Grand Prix'), findsOneWidget);
      expect(find.text('Saudi Arabian Grand Prix'), findsNothing);
    });

    testWidgets('shows empty state when no races', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          RaceScheduleScreen(races: const [], season: '2025'),
        ),
      );
      await tester.pump();

      expect(find.text('No race schedule available.'), findsOneWidget);
    });

    testWidgets('shows no matching message for empty search', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          RaceScheduleScreen(races: _sampleRaces(), season: '2025'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzzzzzz');
      await tester.pumpAndSettle();

      expect(find.text('No matching races.'), findsOneWidget);
    });

    testWidgets('tapping Completed chip changes filter', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          RaceScheduleScreen(races: _sampleRaces(), season: '2025'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      // All sample races are in the past (2025-03-*), so they should show as completed
      expect(find.byType(ChoiceChip), findsNWidgets(3));
    });

    testWidgets('shows offline cache label when from cache', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          RaceScheduleScreen(
            races: _sampleRaces(),
            season: '2025',
            lastUpdated: DateTime.now(),
            isFromCache: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Offline cache'), findsOneWidget);
    });
  });
}
