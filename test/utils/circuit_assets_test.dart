import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/utils/circuit_assets.dart';

void main() {
  group('CircuitAssets', () {
    test('every listed map is a bundled file', () {
      for (final name in CircuitAssets.bundled) {
        final path = 'lib/assets/circuits/$name.svg';
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('every bundled file is listed', () {
      final files = Directory('lib/assets/circuits')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((name) => name.endsWith('.svg'))
          .map((name) => name.substring(0, name.length - 4))
          .toSet();
      expect(files, CircuitAssets.bundled);
    });

    test('maps the API id "vegas" to the Las Vegas file', () {
      expect(
        CircuitAssets.pathFor('vegas'),
        'lib/assets/circuits/las_vegas.svg',
      );
    });

    test('returns null for circuits without a map', () {
      expect(CircuitAssets.pathFor('madring'), isNull);
      expect(CircuitAssets.pathFor(''), isNull);
    });

    test('resolves ids that match the file name', () {
      expect(CircuitAssets.pathFor('monaco'), 'lib/assets/circuits/monaco.svg');
    });
  });
}
