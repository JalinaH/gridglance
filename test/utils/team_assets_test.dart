import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/utils/team_assets.dart';

void main() {
  group('teamLogoAsset', () {
    test('returns asset path for exact lowercase match', () {
      expect(teamLogoAsset('mclaren'), 'assets/teams/mclaren.png');
      expect(teamLogoAsset('ferrari'), 'assets/teams/ferrari.png');
      expect(teamLogoAsset('mercedes'), 'assets/teams/mercedes.png');
    });

    test('matches case-insensitively', () {
      expect(teamLogoAsset('McLaren'), 'assets/teams/mclaren.png');
      expect(teamLogoAsset('FERRARI'), 'assets/teams/ferrari.png');
      expect(teamLogoAsset('Mercedes'), 'assets/teams/mercedes.png');
    });

    test('trims whitespace', () {
      expect(teamLogoAsset('  mclaren  '), 'assets/teams/mclaren.png');
      expect(teamLogoAsset(' ferrari '), 'assets/teams/ferrari.png');
    });

    test('resolves legacy / variation names', () {
      expect(
        teamLogoAsset('Oracle Red Bull Racing'),
        'assets/teams/red_bull.png',
      );
      expect(
        teamLogoAsset('McLaren Mercedes'),
        'assets/teams/mclaren.png',
      );
      expect(
        teamLogoAsset('Mercedes-AMG Petronas'),
        'assets/teams/mercedes.png',
      );
      expect(
        teamLogoAsset('Visa Cash App RB'),
        'assets/teams/rb.png',
      );
      expect(
        teamLogoAsset('Kick Sauber'),
        'assets/teams/sauber.png',
      );
    });

    test('returns null for unknown team', () {
      expect(teamLogoAsset('Unknown Racing'), isNull);
      expect(teamLogoAsset(''), isNull);
    });

    test('maps all 2026 teams', () {
      final teams2026 = {
        'mclaren': 'assets/teams/mclaren.png',
        'mercedes': 'assets/teams/mercedes.png',
        'red bull racing': 'assets/teams/red_bull.png',
        'ferrari': 'assets/teams/ferrari.png',
        'williams': 'assets/teams/williams.png',
        'racing bulls': 'assets/teams/rb.png',
        'aston martin': 'assets/teams/aston_martin.png',
        'haas f1 team': 'assets/teams/haas.png',
        'audi': 'assets/teams/audi.png',
        'alpine': 'assets/teams/alpine.png',
        'cadillac': 'assets/teams/cadillac.png',
      };

      for (final entry in teams2026.entries) {
        expect(
          teamLogoAsset(entry.key),
          entry.value,
          reason: '${entry.key} should map to ${entry.value}',
        );
      }
    });
  });
}
