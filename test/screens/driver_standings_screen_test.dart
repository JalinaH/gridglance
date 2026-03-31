import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/models/driver_standing.dart';
import 'package:gridglance/screens/driver_standings_screen.dart';
import 'package:gridglance/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<DriverStanding> _sampleStandings() => [
      DriverStanding(
        position: '1',
        points: '400',
        wins: '10',
        givenName: 'Max',
        familyName: 'Verstappen',
        teamName: 'Red Bull',
        driverId: 'max_verstappen',
        constructorId: 'red_bull',
        code: 'VER',
        permanentNumber: '1',
        nationality: 'Dutch',
      ),
      DriverStanding(
        position: '2',
        points: '300',
        wins: '5',
        givenName: 'Lewis',
        familyName: 'Hamilton',
        teamName: 'Mercedes',
        driverId: 'hamilton',
        constructorId: 'mercedes',
        code: 'HAM',
        permanentNumber: '44',
        nationality: 'British',
      ),
      DriverStanding(
        position: '3',
        points: '250',
        wins: '3',
        givenName: 'Charles',
        familyName: 'Leclerc',
        teamName: 'Ferrari',
        driverId: 'leclerc',
        constructorId: 'ferrari',
        code: 'LEC',
        permanentNumber: '16',
        nationality: 'Monegasque',
      ),
    ];

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: child,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DriverStandingsScreen', () {
    testWidgets('renders title and season', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          DriverStandingsScreen(
            standings: _sampleStandings(),
            season: '2025',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Driver Standings'), findsWidgets);
      expect(find.text('Season 2025'), findsWidgets);
    });

    testWidgets('renders search field', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          DriverStandingsScreen(
            standings: _sampleStandings(),
            season: '2025',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search drivers or teams'), findsOneWidget);
    });

    testWidgets('displays driver names in the list', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          DriverStandingsScreen(
            standings: _sampleStandings(),
            season: '2025',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Max Verstappen'), findsWidgets);
      expect(find.text('Lewis Hamilton'), findsWidgets);
    });

    testWidgets('search filters drivers', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          DriverStandingsScreen(
            standings: _sampleStandings(),
            season: '2025',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Type in the search field
      await tester.enterText(find.byType(TextField), 'Hamilton');
      await tester.pumpAndSettle();

      // Hamilton should be visible (in list and possibly share card)
      expect(find.text('Lewis Hamilton'), findsWidgets);
      // Leclerc should be filtered out
      expect(find.text('Charles Leclerc'), findsNothing);
    });

    testWidgets('shows empty state when no standings', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          DriverStandingsScreen(standings: const [], season: '2025'),
        ),
      );
      await tester.pump();

      expect(find.text('No driver standings available.'), findsOneWidget);
    });

    testWidgets('shows no matching message for empty search', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          DriverStandingsScreen(
            standings: _sampleStandings(),
            season: '2025',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzzzzzz');
      await tester.pumpAndSettle();

      expect(find.text('No matching drivers.'), findsOneWidget);
    });

    testWidgets('shows last updated text when provided', (tester) async {
      final lastUpdated = DateTime(2025, 6, 15, 10, 30);
      await tester.pumpWidget(
        _wrapWithTheme(
          DriverStandingsScreen(
            standings: _sampleStandings(),
            season: '2025',
            lastUpdated: lastUpdated,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show some form of updated text
      expect(find.textContaining('ago'), findsOneWidget);
    });

    testWidgets('shows offline cache label when from cache', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          DriverStandingsScreen(
            standings: _sampleStandings(),
            season: '2025',
            lastUpdated: DateTime.now(),
            isFromCache: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Offline cache'), findsOneWidget);
    });

    testWidgets('has share button in app bar', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          DriverStandingsScreen(
            standings: _sampleStandings(),
            season: '2025',
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.ios_share), findsOneWidget);
    });
  });
}
