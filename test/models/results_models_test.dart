import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/models/race_result.dart';
import 'package:gridglance/models/session_results.dart';

void main() {
  group('DriverRaceResult.fromRaceJson', () {
    test('maps first race result entry', () {
      final result = DriverRaceResult.fromRaceJson({
        'round': '10',
        'raceName': 'British Grand Prix',
        'date': '2026-07-05',
        'Results': [
          {'position': '2', 'points': '18', 'status': '+3.211s'},
        ],
      });

      expect(result.round, '10');
      expect(result.raceName, 'British Grand Prix');
      expect(result.date, '2026-07-05');
      expect(result.position, '2');
      expect(result.points, '18');
      expect(result.status, '+3.211s');
    });

    test('uses defaults when Results is empty', () {
      final result = DriverRaceResult.fromRaceJson({
        'round': '11',
        'raceName': 'Hungarian Grand Prix',
        'date': '2026-07-19',
        'Results': [],
      });

      expect(result.position, '-');
      expect(result.points, '0');
      expect(result.status, '');
    });
  });

  group('TeamRaceResult.fromRaceJson', () {
    test('maps all team driver results', () {
      final result = TeamRaceResult.fromRaceJson({
        'round': '12',
        'raceName': 'Belgian Grand Prix',
        'date': '2026-08-02',
        'Results': [
          {
            'position': '1',
            'points': '25',
            'Driver': {
              'givenName': 'Lando',
              'familyName': 'Norris',
              'code': 'NOR',
              'permanentNumber': '4',
            },
          },
          {
            'position': '5',
            'points': '10',
            'Driver': {
              'givenName': 'Oscar',
              'familyName': 'Piastri',
              'code': 'PIA',
              'permanentNumber': '81',
            },
          },
        ],
      });

      expect(result.round, '12');
      expect(result.drivers.length, 2);
      expect(result.drivers.first.givenName, 'Lando');
      expect(result.drivers.first.familyName, 'Norris');
      expect(result.drivers.first.position, '1');
      expect(result.drivers.first.points, '25');
      expect(result.drivers.last.code, 'PIA');
      expect(result.drivers.last.permanentNumber, '81');
    });
  });

  group('DriverSprintResult.fromRaceJson', () {
    test('maps sprint points for a driver', () {
      final result = DriverSprintResult.fromRaceJson({
        'round': '6',
        'raceName': 'Miami Grand Prix',
        'date': '2026-05-03',
        'SprintResults': [
          {'points': '7'},
        ],
      });

      expect(result.round, '6');
      expect(result.raceName, 'Miami Grand Prix');
      expect(result.date, '2026-05-03');
      expect(result.points, '7');
    });
  });

  group('TeamSprintResult.fromRaceJson', () {
    test('maps sprint points for both team cars', () {
      final result = TeamSprintResult.fromRaceJson({
        'round': '7',
        'raceName': 'Emilia Romagna Grand Prix',
        'date': '2026-05-17',
        'SprintResults': [
          {'points': '8'},
          {'points': '3'},
        ],
      });

      expect(result.round, '7');
      expect(result.raceName, 'Emilia Romagna Grand Prix');
      expect(result.date, '2026-05-17');
      expect(result.points, ['8', '3']);
    });
  });

  group('ResultEntry.fromJson', () {
    test('maps race results and prefers time in timeOrStatus', () {
      final entry = ResultEntry.fromJson({
        'position': '3',
        'points': '15',
        'status': 'Finished',
        'Time': {'time': '+7.981s'},
        'Driver': {'givenName': 'Charles', 'familyName': 'Leclerc'},
        'Constructor': {'name': 'Ferrari'},
      }, type: SessionType.race);

      expect(entry.position, '3');
      expect(entry.driverName, 'Charles Leclerc');
      expect(entry.teamName, 'Ferrari');
      expect(entry.points, '15');
      expect(entry.time, '+7.981s');
      expect(entry.q1, null);
      expect(entry.q2, null);
      expect(entry.q3, null);
      expect(entry.timeOrStatus, '+7.981s');
    });

    test('maps qualifying laps and falls back to status', () {
      final entry = ResultEntry.fromJson({
        'position': '1',
        'points': '0',
        'status': 'Finished',
        'Q1': '1:26.001',
        'Q2': '1:25.421',
        'Q3': '1:25.102',
        'Driver': {'givenName': 'George', 'familyName': 'Russell'},
        'Constructor': {'name': 'Mercedes'},
      }, type: SessionType.qualifying);

      expect(entry.driverName, 'George Russell');
      expect(entry.teamName, 'Mercedes');
      expect(entry.q1, '1:26.001');
      expect(entry.q2, '1:25.421');
      expect(entry.q3, '1:25.102');
      expect(entry.time, null);
      expect(entry.timeOrStatus, 'Finished');
    });
  });

  group('DriverQualifyingResult.fromRaceJson', () {
    test('maps qualifying position for a driver', () {
      final result = DriverQualifyingResult.fromRaceJson({
        'round': '9',
        'raceName': 'Canadian Grand Prix',
        'date': '2026-06-14',
        'QualifyingResults': [
          {'position': '4'},
        ],
      });

      expect(result.round, '9');
      expect(result.raceName, 'Canadian Grand Prix');
      expect(result.date, '2026-06-14');
      expect(result.position, '4');
    });
  });

  group('TeamQualifyingResult.fromRaceJson', () {
    test('maps qualifying positions for both team cars', () {
      final result = TeamQualifyingResult.fromRaceJson({
        'round': '10',
        'raceName': 'Austrian Grand Prix',
        'date': '2026-06-28',
        'QualifyingResults': [
          {'position': '2'},
          {'position': '7'},
        ],
      });

      expect(result.round, '10');
      expect(result.raceName, 'Austrian Grand Prix');
      expect(result.date, '2026-06-28');
      expect(result.positions, ['2', '7']);
    });
  });
}
