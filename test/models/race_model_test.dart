import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/models/race.dart';

void main() {
  group('Race.fromJson', () {
    test('parses race, location, and available sessions', () {
      final race = Race.fromJson({
        'round': '1',
        'raceName': 'Australian Grand Prix',
        'date': '2026-03-08',
        'time': '06:00:00Z',
        'Circuit': {
          'circuitName': 'Albert Park Grand Prix Circuit',
          'Location': {
            'locality': 'Melbourne',
            'country': 'Australia',
            'lat': '-37.8497',
            'long': '144.968',
          },
        },
        'FirstPractice': {'date': '2026-03-06', 'time': '01:30:00Z'},
        'SecondPractice': {'date': '2026-03-06', 'time': '05:00:00Z'},
        'Qualifying': {'date': '2026-03-07', 'time': '06:00:00Z'},
        'Sprint': {'date': '2026-03-07', 'time': '22:00:00Z'},
      });

      expect(race.round, '1');
      expect(race.raceName, 'Australian Grand Prix');
      expect(race.circuitName, 'Albert Park Grand Prix Circuit');
      expect(race.location, 'Melbourne, Australia');
      expect(race.latitude, closeTo(-37.8497, 0.0001));
      expect(race.longitude, closeTo(144.968, 0.0001));
      expect(race.displayDateTime, '2026-03-08 06:00:00Z');
      expect(race.startDateTime, DateTime.parse('2026-03-08T06:00:00Z'));
      expect(race.sessions.map((session) => session.name).toList(), [
        'Free Practice 1',
        'Free Practice 2',
        'Qualifying',
        'Sprint',
        'Race',
      ]);
    });

    test('uses safe defaults when json is sparse', () {
      final race = Race.fromJson({});

      expect(race.round, '');
      expect(race.raceName, '');
      expect(race.date, '');
      expect(race.time, null);
      expect(race.circuitName, '');
      expect(race.locality, '');
      expect(race.country, '');
      expect(race.latitude, null);
      expect(race.longitude, null);
      expect(race.sessions.length, 1);
      expect(race.sessions.first.name, 'Race');
      expect(race.startDateTime, null);
      expect(race.location, '');
    });
  });

  group('Race.location', () {
    test('falls back to country when locality is empty', () {
      final race = Race(
        round: '5',
        raceName: 'Sample GP',
        date: '2026-05-01',
        time: '12:00:00Z',
        circuitName: 'Sample Circuit',
        locality: '',
        country: 'Italy',
        practice1: null,
        practice2: null,
        practice3: null,
        qualifying: null,
        sprintQualifying: null,
        sprint: null,
      );

      expect(race.location, 'Italy');
    });

    test('falls back to locality when country is empty', () {
      final race = Race(
        round: '6',
        raceName: 'Sample GP',
        date: '2026-05-08',
        time: '12:00:00Z',
        circuitName: 'Sample Circuit',
        locality: 'Monaco',
        country: '',
        practice1: null,
        practice2: null,
        practice3: null,
        qualifying: null,
        sprintQualifying: null,
        sprint: null,
      );

      expect(race.location, 'Monaco');
    });
  });

  group('RaceSession.startDateTime', () {
    test('parses time values with a leading T', () {
      final session = RaceSession(
        name: 'Race',
        date: '2026-03-08',
        time: 'T06:00:00Z',
      );

      expect(session.startDateTime, DateTime.parse('2026-03-08T06:00:00Z'));
    });

    test('parses date-only values when time is missing', () {
      final session = RaceSession(name: 'Race', date: '2026-03-08', time: null);

      expect(session.startDateTime, DateTime.parse('2026-03-08'));
      expect(session.displayDateTime, '2026-03-08');
    });
  });
}
