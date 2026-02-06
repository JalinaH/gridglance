import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/models/constructor_standing.dart';
import 'package:gridglance/models/driver_standing.dart';

void main() {
  group('DriverStanding.fromJson', () {
    test('maps driver and constructor fields', () {
      final standing = DriverStanding.fromJson({
        'position': '1',
        'points': '120',
        'wins': '4',
        'Driver': {
          'driverId': 'max_verstappen',
          'givenName': 'Max',
          'familyName': 'Verstappen',
          'code': 'VER',
          'permanentNumber': '1',
        },
        'Constructors': [
          {'constructorId': 'red_bull', 'name': 'Red Bull Racing'},
        ],
      });

      expect(standing.position, '1');
      expect(standing.points, '120');
      expect(standing.wins, '4');
      expect(standing.givenName, 'Max');
      expect(standing.familyName, 'Verstappen');
      expect(standing.driverId, 'max_verstappen');
      expect(standing.code, 'VER');
      expect(standing.permanentNumber, '1');
      expect(standing.constructorId, 'red_bull');
      expect(standing.teamName, 'Red Bull Racing');
    });

    test('uses defaults when optional fields are missing', () {
      final standing = DriverStanding.fromJson({});

      expect(standing.position, '-');
      expect(standing.points, '0');
      expect(standing.wins, '0');
      expect(standing.givenName, '');
      expect(standing.familyName, '');
      expect(standing.driverId, '');
      expect(standing.constructorId, '');
      expect(standing.teamName, '');
      expect(standing.code, null);
      expect(standing.permanentNumber, null);
    });
  });

  group('ConstructorStanding.fromJson', () {
    test('maps constructor fields', () {
      final standing = ConstructorStanding.fromJson({
        'position': '2',
        'points': '98',
        'wins': '1',
        'Constructor': {'constructorId': 'ferrari', 'name': 'Ferrari'},
      });

      expect(standing.position, '2');
      expect(standing.points, '98');
      expect(standing.wins, '1');
      expect(standing.constructorId, 'ferrari');
      expect(standing.teamName, 'Ferrari');
    });

    test('uses defaults when fields are missing', () {
      final standing = ConstructorStanding.fromJson({});

      expect(standing.position, '-');
      expect(standing.points, '0');
      expect(standing.wins, '0');
      expect(standing.constructorId, '');
      expect(standing.teamName, '');
    });
  });
}
