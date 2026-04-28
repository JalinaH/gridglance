import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/utils/json_safe.dart';

void main() {
  group('JsonSafe.asMap', () {
    test('returns a typed map untouched', () {
      final m = <String, dynamic>{'a': 1};
      expect(identical(JsonSafe.asMap(m), m), isTrue);
    });

    test('casts a generic Map to Map<String, dynamic>', () {
      final raw = <dynamic, dynamic>{'a': 1, 'b': 'x'};
      final result = JsonSafe.asMap(raw);
      expect(result, {'a': 1, 'b': 'x'});
    });

    test('returns an empty map on null', () {
      expect(JsonSafe.asMap(null), isEmpty);
    });

    test('returns an empty map on a non-map type', () {
      expect(JsonSafe.asMap('not a map'), isEmpty);
      expect(JsonSafe.asMap(<int>[1, 2]), isEmpty);
      expect(JsonSafe.asMap(42), isEmpty);
    });
  });

  group('JsonSafe.asMapOrNull', () {
    test('returns null on a non-map type', () {
      expect(JsonSafe.asMapOrNull(null), isNull);
      expect(JsonSafe.asMapOrNull('x'), isNull);
      expect(JsonSafe.asMapOrNull(<int>[1]), isNull);
    });

    test('returns the cast map on a generic Map', () {
      final raw = <dynamic, dynamic>{'a': 1};
      expect(JsonSafe.asMapOrNull(raw), {'a': 1});
    });
  });

  group('JsonSafe.asList', () {
    test('returns the list untouched', () {
      final l = <dynamic>[1, 2, 3];
      expect(identical(JsonSafe.asList(l), l), isTrue);
    });

    test('returns an empty list on null or non-list types', () {
      expect(JsonSafe.asList(null), isEmpty);
      expect(JsonSafe.asList('x'), isEmpty);
      expect(JsonSafe.asList(<String, dynamic>{'a': 1}), isEmpty);
    });
  });

  group('JsonReader.string / optString', () {
    test('returns the string value', () {
      final reader = JsonReader({'name': 'Verstappen'});
      expect(reader.string('name'), 'Verstappen');
      expect(reader.optString('name'), 'Verstappen');
    });

    test('coerces non-string scalars via toString', () {
      final reader = JsonReader({'n': 42, 'd': 3.14, 'b': true});
      expect(reader.string('n'), '42');
      expect(reader.string('d'), '3.14');
      expect(reader.string('b'), 'true');
    });

    test('returns the default value when the key is missing', () {
      final reader = JsonReader({});
      expect(reader.string('missing'), '');
      expect(reader.string('missing', defaultValue: '-'), '-');
    });

    test('optString returns null for a missing key', () {
      final reader = JsonReader({});
      expect(reader.optString('missing'), isNull);
    });
  });

  group('JsonReader.optInt / optDouble', () {
    test('parses numeric strings', () {
      final reader = JsonReader({'pos': '3', 'lat': '52.0786'});
      expect(reader.optInt('pos'), 3);
      expect(reader.optDouble('lat'), closeTo(52.0786, 1e-6));
    });

    test('returns numeric values as-is', () {
      final reader = JsonReader({'n': 7, 'd': 1.5});
      expect(reader.optInt('n'), 7);
      expect(reader.optDouble('d'), 1.5);
    });

    test('returns null for unparseable strings or missing keys', () {
      final reader = JsonReader({'n': 'not-a-number'});
      expect(reader.optInt('n'), isNull);
      expect(reader.optInt('missing'), isNull);
      expect(reader.optDouble('missing'), isNull);
    });
  });

  group('JsonReader.requireMap / optMap', () {
    test('requireMap returns a JsonReader over the nested object', () {
      final reader = JsonReader({
        'Driver': {'givenName': 'Max'},
      });
      expect(reader.requireMap('Driver').string('givenName'), 'Max');
    });

    test('requireMap returns an empty reader when the key is missing', () {
      final reader = JsonReader({});
      expect(reader.requireMap('missing').optString('any'), isNull);
    });

    test('optMap returns null when the key is absent or not an object', () {
      final reader = JsonReader({'Driver': 'oops'});
      expect(reader.optMap('missing'), isNull);
      expect(reader.optMap('Driver'), isNull);
    });
  });

  group('JsonReader.readers', () {
    test('yields one JsonReader per object entry', () {
      final reader = JsonReader({
        'items': [
          {'id': 'a'},
          {'id': 'b'},
        ],
      });
      final ids = reader.readers('items').map((r) => r.string('id')).toList();
      expect(ids, ['a', 'b']);
    });

    test('skips non-object items in the list', () {
      final reader = JsonReader({
        'items': [
          {'id': 'a'},
          'not a map',
          42,
          {'id': 'b'},
        ],
      });
      final ids = reader.readers('items').map((r) => r.string('id')).toList();
      expect(ids, ['a', 'b']);
    });

    test('returns an empty iterable when the list is missing', () {
      final reader = JsonReader({});
      expect(reader.readers('missing').isEmpty, isTrue);
    });
  });
}
