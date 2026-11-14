import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/widgets/team_logo.dart';

void main() {
  group('TeamLogo', () {
    test('every mapped logo is a file that ships with the app', () {
      for (final asset in TeamLogo.bundledAssets) {
        expect(File(asset).existsSync(), isTrue, reason: '$asset is missing');
      }
    });

    test('resolves the names the API uses for the current grid', () {
      const names = [
        'McLaren',
        'Mercedes',
        'Red Bull',
        'Ferrari',
        'Williams',
        'RB F1 Team',
        'Aston Martin',
        'Haas F1 Team',
        'Audi',
        'Alpine F1 Team',
        'Cadillac F1 Team',
      ];
      for (final name in names) {
        expect(TeamLogo.assetFor(name), isNotNull, reason: name);
      }
    });

    test('prefers the most specific match', () {
      expect(TeamLogo.assetFor('Red Bull Racing'), endsWith('red-bull.png'));
      expect(TeamLogo.assetFor('Racing Bulls'), endsWith('rb.png'));
    });

    test('returns null for an unknown or empty team', () {
      expect(TeamLogo.assetFor('Unknown Racing'), isNull);
      expect(TeamLogo.assetFor(''), isNull);
    });
  });
}
