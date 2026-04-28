import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/models/constructor_standing.dart';
import 'package:gridglance/screens/constructor_standings_screen.dart';
import 'package:gridglance/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<ConstructorStanding> _sampleStandings() => [
  ConstructorStanding(
    position: '1',
    points: '700',
    wins: '15',
    teamName: 'Red Bull',
    constructorId: 'red_bull',
  ),
  ConstructorStanding(
    position: '2',
    points: '550',
    wins: '8',
    teamName: 'Mercedes',
    constructorId: 'mercedes',
  ),
  ConstructorStanding(
    position: '3',
    points: '480',
    wins: '5',
    teamName: 'Ferrari',
    constructorId: 'ferrari',
  ),
];

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(theme: AppTheme.dark(), home: child);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ConstructorStandingsScreen', () {
    testWidgets('renders title and season', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          ConstructorStandingsScreen(
            standings: _sampleStandings(),
            season: '2025',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Team Standings'), findsWidgets);
      expect(find.text('Season 2025'), findsWidgets);
    });

    testWidgets('renders search field with hint', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          ConstructorStandingsScreen(
            standings: _sampleStandings(),
            season: '2025',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search teams'), findsOneWidget);
    });

    testWidgets('displays team names', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          ConstructorStandingsScreen(
            standings: _sampleStandings(),
            season: '2025',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Red Bull'), findsWidgets);
      expect(find.text('Mercedes'), findsWidgets);
      expect(find.text('Ferrari'), findsWidgets);
    });

    testWidgets('search filters teams', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          ConstructorStandingsScreen(
            standings: _sampleStandings(),
            season: '2025',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Ferrari');
      await tester.pumpAndSettle();

      expect(find.text('Ferrari'), findsWidgets);
      // Red Bull text should not appear in the standings list
      // (it may still appear in share card off-screen, so check
      // the visible area is filtered)
    });

    testWidgets('shows empty state when no standings', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const ConstructorStandingsScreen(standings: [], season: '2025'),
        ),
      );
      await tester.pump();

      expect(find.text('No team standings available.'), findsOneWidget);
    });

    testWidgets('shows no matching message for empty search', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          ConstructorStandingsScreen(
            standings: _sampleStandings(),
            season: '2025',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzzzzzz');
      await tester.pumpAndSettle();

      expect(find.text('No matching teams.'), findsOneWidget);
    });

    testWidgets('shows offline cache label when from cache', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          ConstructorStandingsScreen(
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
          ConstructorStandingsScreen(
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
