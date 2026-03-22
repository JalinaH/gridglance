import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/models/race.dart';
import 'package:gridglance/services/notification_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Race race;
  late RaceSession session;

  setUp(() {
    race = Race(
      round: '5',
      raceName: 'Monaco Grand Prix',
      date: '2026-05-24',
      time: '13:00:00Z',
      circuitName: 'Circuit de Monaco',
      locality: 'Monte-Carlo',
      country: 'Monaco',
      practice1: null,
      practice2: null,
      practice3: null,
      qualifying: null,
      sprintQualifying: null,
      sprint: null,
    );
    session = RaceSession(
      name: 'Qualifying',
      date: '2026-05-23',
      time: '14:00:00Z',
    );
  });

  group('NotificationPreferences.scheduledRace', () {
    test('returns null when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final result = await NotificationPreferences.getScheduledRace();
      expect(result, isNull);
    });

    test('stores and retrieves a scheduled race value', () async {
      SharedPreferences.setMockInitialValues({});
      await NotificationPreferences.setScheduledRace('2026|5|Monaco');
      final result = await NotificationPreferences.getScheduledRace();
      expect(result, '2026|5|Monaco');
    });
  });

  group('NotificationPreferences.sessionEnabled', () {
    test('defaults to false when not set', () async {
      SharedPreferences.setMockInitialValues({});
      final enabled = await NotificationPreferences.isSessionEnabled(
        race: race,
        session: session,
        season: '2026',
      );
      expect(enabled, isFalse);
    });

    test('stores and retrieves enabled state', () async {
      SharedPreferences.setMockInitialValues({});
      await NotificationPreferences.setSessionEnabled(
        race: race,
        session: session,
        season: '2026',
        value: true,
      );
      final enabled = await NotificationPreferences.isSessionEnabled(
        race: race,
        session: session,
        season: '2026',
      );
      expect(enabled, isTrue);
    });

    test('can disable a previously enabled session', () async {
      SharedPreferences.setMockInitialValues({});
      await NotificationPreferences.setSessionEnabled(
        race: race,
        session: session,
        season: '2026',
        value: true,
      );
      await NotificationPreferences.setSessionEnabled(
        race: race,
        session: session,
        season: '2026',
        value: false,
      );
      final enabled = await NotificationPreferences.isSessionEnabled(
        race: race,
        session: session,
        season: '2026',
      );
      expect(enabled, isFalse);
    });
  });

  group('NotificationPreferences.sessionLeadTime', () {
    test('defaults to 15 minutes when not set', () async {
      SharedPreferences.setMockInitialValues({});
      final minutes = await NotificationPreferences.getSessionLeadTimeMinutes(
        race: race,
        session: session,
        season: '2026',
      );
      expect(minutes, 15);
    });

    test('stores and retrieves a valid lead time', () async {
      SharedPreferences.setMockInitialValues({});
      await NotificationPreferences.setSessionLeadTimeMinutes(
        race: race,
        session: session,
        season: '2026',
        minutes: 60,
      );
      final minutes = await NotificationPreferences.getSessionLeadTimeMinutes(
        race: race,
        session: session,
        season: '2026',
      );
      expect(minutes, 60);
    });

    test('falls back to default for non-preset values', () async {
      SharedPreferences.setMockInitialValues({});
      await NotificationPreferences.setSessionLeadTimeMinutes(
        race: race,
        session: session,
        season: '2026',
        minutes: 999,
      );
      final minutes = await NotificationPreferences.getSessionLeadTimeMinutes(
        race: race,
        session: session,
        season: '2026',
      );
      expect(minutes, NotificationPreferences.defaultLeadTimeMinutes);
    });
  });

  group('NotificationPreferences.weekendDigest', () {
    test('defaults to false when not set', () async {
      SharedPreferences.setMockInitialValues({});
      final enabled = await NotificationPreferences.isWeekendDigestEnabled(
        race: race,
        season: '2026',
      );
      expect(enabled, isFalse);
    });

    test('stores and retrieves enabled state', () async {
      SharedPreferences.setMockInitialValues({});
      await NotificationPreferences.setWeekendDigestEnabled(
        race: race,
        season: '2026',
        value: true,
      );
      final enabled = await NotificationPreferences.isWeekendDigestEnabled(
        race: race,
        season: '2026',
      );
      expect(enabled, isTrue);
    });
  });

  group('NotificationPreferences.favoriteSessionFinished', () {
    test('defaults to false', () async {
      SharedPreferences.setMockInitialValues({});
      final enabled =
          await NotificationPreferences.isFavoriteSessionFinishedEnabled();
      expect(enabled, isFalse);
    });

    test('stores and retrieves enabled state', () async {
      SharedPreferences.setMockInitialValues({});
      await NotificationPreferences.setFavoriteSessionFinishedEnabled(true);
      final enabled =
          await NotificationPreferences.isFavoriteSessionFinishedEnabled();
      expect(enabled, isTrue);
    });
  });

  group('NotificationPreferences.favoritePositionPoints', () {
    test('defaults to false', () async {
      SharedPreferences.setMockInitialValues({});
      final enabled =
          await NotificationPreferences.isFavoritePositionPointsEnabled();
      expect(enabled, isFalse);
    });

    test('stores and retrieves enabled state', () async {
      SharedPreferences.setMockInitialValues({});
      await NotificationPreferences.setFavoritePositionPointsEnabled(true);
      final enabled =
          await NotificationPreferences.isFavoritePositionPointsEnabled();
      expect(enabled, isTrue);
    });
  });

  group('NotificationPreferences.leadTimePresets', () {
    test('contains expected preset values', () {
      expect(
        NotificationPreferences.leadTimePresets,
        containsAll([5, 15, 60, 1440]),
      );
    });

    test('defaultLeadTimeMinutes is in presets', () {
      expect(
        NotificationPreferences.leadTimePresets,
        contains(NotificationPreferences.defaultLeadTimeMinutes),
      );
    });
  });
}
