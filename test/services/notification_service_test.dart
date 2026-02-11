import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/models/race.dart';
import 'package:gridglance/services/notification_service.dart';

void main() {
  group('NotificationService.sessionKey', () {
    test('encodes season, race, and session identity data', () {
      final race = _buildRace(round: '1');
      final session = RaceSession(
        name: 'Qualifying',
        date: '2026-03-07',
        time: '06:00:00Z',
      );

      final key = NotificationService.sessionKey(
        race: race,
        session: session,
        season: '2026',
      );
      final decoded = utf8.decode(base64Url.decode(base64Url.normalize(key)));

      expect(decoded, '2026|1|Qualifying|2026-03-07|06:00:00Z');
    });
  });

  group('NotificationService.weekendDigestKey', () {
    test('encodes season and race weekend identity data', () {
      final race = _buildRace(round: '7');

      final key = NotificationService.weekendDigestKey(
        race: race,
        season: '2026',
      );
      final decoded = utf8.decode(base64Url.decode(base64Url.normalize(key)));

      expect(decoded, 'digest|2026|7|Sample Grand Prix|2026-03-08|06:00:00Z');
    });
  });

  group('NotificationService.notificationIdForSession', () {
    test('returns deterministic non-negative ids', () {
      final race = _buildRace(round: '3');
      final session = RaceSession(
        name: 'Race',
        date: '2026-04-01',
        time: '13:00:00Z',
      );

      final first = NotificationService.notificationIdForSession(
        race: race,
        session: session,
        season: '2026',
      );
      final second = NotificationService.notificationIdForSession(
        race: race,
        session: session,
        season: '2026',
      );

      expect(first, second);
      expect(first, greaterThanOrEqualTo(0));
    });

    test('changes id when session identity changes', () {
      final race = _buildRace(round: '4');
      final qualifying = RaceSession(
        name: 'Qualifying',
        date: '2026-04-11',
        time: '09:00:00Z',
      );
      final raceSession = RaceSession(
        name: 'Race',
        date: '2026-04-12',
        time: '09:00:00Z',
      );

      final qualifyingId = NotificationService.notificationIdForSession(
        race: race,
        session: qualifying,
        season: '2026',
      );
      final raceId = NotificationService.notificationIdForSession(
        race: race,
        session: raceSession,
        season: '2026',
      );

      expect(qualifyingId, isNot(raceId));
    });
  });

  group('NotificationService.notificationIdForWeekendDigest', () {
    test('returns deterministic non-negative ids', () {
      final race = _buildRace(round: '9');

      final first = NotificationService.notificationIdForWeekendDigest(
        race: race,
        season: '2026',
      );
      final second = NotificationService.notificationIdForWeekendDigest(
        race: race,
        season: '2026',
      );

      expect(first, second);
      expect(first, greaterThanOrEqualTo(0));
    });

    test('changes when race weekend identity changes', () {
      final firstRace = _buildRace(round: '10');
      final secondRace = _buildRace(round: '11');

      final firstId = NotificationService.notificationIdForWeekendDigest(
        race: firstRace,
        season: '2026',
      );
      final secondId = NotificationService.notificationIdForWeekendDigest(
        race: secondRace,
        season: '2026',
      );

      expect(firstId, isNot(secondId));
    });
  });

  group('NotificationService.notificationIdForFavoriteAlert', () {
    test('returns deterministic ids for the same payload', () {
      final first = NotificationService.notificationIdForFavoriteAlert(
        season: '2026',
        entityType: 'driver',
        entityId: 'verstappen',
        category: 'position_points',
        eventKey: '2026|driver|1|350',
      );
      final second = NotificationService.notificationIdForFavoriteAlert(
        season: '2026',
        entityType: 'driver',
        entityId: 'verstappen',
        category: 'position_points',
        eventKey: '2026|driver|1|350',
      );

      expect(first, second);
      expect(first, greaterThanOrEqualTo(0));
    });

    test('changes when category or event changes', () {
      final sessionId = NotificationService.notificationIdForFavoriteAlert(
        season: '2026',
        entityType: 'team',
        entityId: 'ferrari',
        category: 'session_finished',
        eventKey: 'race|3|australia',
      );
      final standingsId = NotificationService.notificationIdForFavoriteAlert(
        season: '2026',
        entityType: 'team',
        entityId: 'ferrari',
        category: 'position_points',
        eventKey: '2026|team|2|300',
      );

      expect(sessionId, isNot(standingsId));
    });
  });
}

Race _buildRace({required String round}) {
  return Race(
    round: round,
    raceName: 'Sample Grand Prix',
    date: '2026-03-08',
    time: '06:00:00Z',
    circuitName: 'Sample Circuit',
    locality: 'Sample City',
    country: 'Sample Country',
    practice1: null,
    practice2: null,
    practice3: null,
    qualifying: null,
    sprintQualifying: null,
    sprint: null,
  );
}
