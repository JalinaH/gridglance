import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/models/session_results.dart';
import 'package:gridglance/services/notification_target.dart';

void main() {
  group('NotificationTarget', () {
    const targets = [
      NotificationTarget.race(season: '2026', round: '21'),
      NotificationTarget.sessionResults(
        season: '2026',
        session: SessionType.qualifying,
      ),
      NotificationTarget.driver(season: '2026', driverId: 'norris'),
      NotificationTarget.team(season: '2026', constructorId: 'mclaren'),
    ];

    test('every destination survives an encode and decode', () {
      for (final target in targets) {
        expect(NotificationTarget.decode(target.encode()), target);
      }
    });

    test('ignores empty and non-JSON payloads', () {
      expect(NotificationTarget.decode(null), isNull);
      expect(NotificationTarget.decode(''), isNull);
      expect(NotificationTarget.decode('not json'), isNull);
      expect(NotificationTarget.decode('[]'), isNull);
    });

    test('ignores payloads from another format version', () {
      final payload = jsonEncode({
        'v': 2,
        'to': 'race',
        'season': '2026',
        'round': '21',
      });

      expect(NotificationTarget.decode(payload), isNull);
    });

    test('ignores unknown destinations and sessions', () {
      String payload(Map<String, Object> fields) =>
          jsonEncode({'v': 1, 'season': '2026', ...fields});

      expect(NotificationTarget.decode(payload({'to': 'podcast'})), isNull);
      expect(
        NotificationTarget.decode(
          payload({'to': 'sessionResults', 'session': 'practice'}),
        ),
        isNull,
      );
    });

    test('rejects a target missing what it needs', () {
      String payload(Map<String, Object> fields) =>
          jsonEncode({'v': 1, ...fields});

      expect(
        NotificationTarget.decode(payload({'to': 'race', 'season': '2026'})),
        isNull,
      );
      expect(
        NotificationTarget.decode(payload({'to': 'driver', 'id': 'norris'})),
        isNull,
      );
      expect(
        NotificationTarget.decode(
          payload({'to': 'team', 'season': '2026', 'id': '  '}),
        ),
        isNull,
      );
    });
  });
}
