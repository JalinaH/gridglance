import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/data/api_service.dart';
import 'package:gridglance/models/constructor_standing.dart';
import 'package:gridglance/models/driver_standing.dart';
import 'package:gridglance/models/race.dart';
import 'package:gridglance/models/session_results.dart';
import 'package:gridglance/services/favorite_result_alert_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Swallow any calls into flutter_local_notifications so the deeper code
  // paths don't fail with MissingPluginException in unit tests.
  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FavoriteResultAlertService.resetForTesting();
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
          // The plugin's `initialize` expects a non-null bool; everything
          // else can return null.
          if (call.method == 'initialize') return true;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
  });

  group('checkForUpdates - dedup wrapper', () {
    test('concurrent callers both resolve without error', () async {
      await Future.wait([
        FavoriteResultAlertService.checkForUpdates(),
        FavoriteResultAlertService.checkForUpdates(),
      ]);
    });

    test('completes successfully when no favorites are set', () async {
      await FavoriteResultAlertService.checkForUpdates();
    });

    test('can be invoked again after the previous run finishes', () async {
      await FavoriteResultAlertService.checkForUpdates();
      await FavoriteResultAlertService.checkForUpdates();
    });
  });

  group('checkForUpdates - notification settings gate', () {
    test('does no work when both notification toggles are disabled',
        () async {
      // Both flags default to false, so no SharedPreferences keys for the
      // baselines should be written even if a favorite is configured.
      SharedPreferences.setMockInitialValues({
        'favorite_driver_id': 'verstappen',
        'notify_favorite_session_finished': false,
        'notify_favorite_position_points': false,
      });
      FavoriteResultAlertService.apiFactory = _FakeApiService.new;

      await FavoriteResultAlertService.checkForUpdates(season: '2026');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('favorite_alert_session_seeded|2026'), isNull);
      expect(prefs.getBool('favorite_alert_standings_seeded|2026'), isNull);
    });
  });

  group('checkForUpdates - session finished alerts', () {
    test('seeds the session baseline on the first run, no alerts fired',
        () async {
      SharedPreferences.setMockInitialValues({
        'favorite_driver_id': 'verstappen',
        'notify_favorite_session_finished': true,
      });
      final fake = _FakeApiService(
        lastRace: _buildSession(
          type: SessionType.race,
          round: '5',
          raceName: 'Spanish GP',
        ),
      );
      FavoriteResultAlertService.apiFactory = () => fake;

      await FavoriteResultAlertService.checkForUpdates(season: '2026');

      final prefs = await SharedPreferences.getInstance();
      // Seeded flag flips on so subsequent runs go through the alert path.
      expect(prefs.getBool('favorite_alert_session_seeded|2026'), isTrue);
      // Baseline contains the seeded event key for the race session.
      final raceKey = prefs.getString(
        'favorite_alert_last_session|2026|race',
      );
      expect(raceKey, isNotNull);
      expect(raceKey, contains('Spanish GP'));
    });

    test('updates the baseline when a new race is reported', () async {
      SharedPreferences.setMockInitialValues({
        'favorite_driver_id': 'verstappen',
        'notify_favorite_session_finished': true,
      });
      final fake = _FakeApiService(
        lastRace: _buildSession(
          type: SessionType.race,
          round: '5',
          raceName: 'Spanish GP',
        ),
      );
      FavoriteResultAlertService.apiFactory = () => fake;

      // First run seeds baseline at round 5.
      await FavoriteResultAlertService.checkForUpdates(season: '2026');

      // Force the debounce interval to elapse before the second run, then
      // swap the API to report round 6 as the latest race.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'favorite_alert_last_check_at',
        DateTime.now()
            .subtract(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
      );
      fake.lastRace = _buildSession(
        type: SessionType.race,
        round: '6',
        raceName: 'Canadian GP',
      );

      await FavoriteResultAlertService.checkForUpdates(season: '2026');

      final newKey = prefs.getString('favorite_alert_last_session|2026|race');
      expect(newKey, isNotNull);
      expect(newKey, contains('Canadian GP'));
    });

    test('a second run with unchanged data leaves the baseline alone',
        () async {
      SharedPreferences.setMockInitialValues({
        'favorite_driver_id': 'verstappen',
        'notify_favorite_session_finished': true,
      });
      final fake = _FakeApiService(
        lastRace: _buildSession(
          type: SessionType.race,
          round: '5',
          raceName: 'Spanish GP',
        ),
      );
      FavoriteResultAlertService.apiFactory = () => fake;

      await FavoriteResultAlertService.checkForUpdates(season: '2026');
      final prefs = await SharedPreferences.getInstance();
      final firstKey = prefs.getString(
        'favorite_alert_last_session|2026|race',
      );

      await prefs.setInt(
        'favorite_alert_last_check_at',
        DateTime.now()
            .subtract(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
      );

      await FavoriteResultAlertService.checkForUpdates(season: '2026');
      final secondKey = prefs.getString(
        'favorite_alert_last_session|2026|race',
      );

      expect(secondKey, firstKey);
    });
  });

  group('checkForUpdates - standings change detection', () {
    test('seeds standings baseline on first run, fires nothing', () async {
      SharedPreferences.setMockInitialValues({
        'favorite_driver_id': 'verstappen',
        'notify_favorite_position_points': true,
      });
      final fake = _FakeApiService(
        driverStandings: [
          _buildDriverStanding(
            driverId: 'verstappen',
            position: '1',
            points: '350',
          ),
        ],
      );
      FavoriteResultAlertService.apiFactory = () => fake;

      await FavoriteResultAlertService.checkForUpdates(season: '2026');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('favorite_alert_standings_seeded|2026'), isTrue);
      expect(
        prefs.getString('favorite_alert_driver_position|2026|verstappen'),
        '1',
      );
      expect(
        prefs.getString('favorite_alert_driver_points|2026|verstappen'),
        '350',
      );
    });

    test('updates baseline when position or points change', () async {
      SharedPreferences.setMockInitialValues({
        'favorite_driver_id': 'verstappen',
        'notify_favorite_position_points': true,
      });
      final fake = _FakeApiService(
        driverStandings: [
          _buildDriverStanding(
            driverId: 'verstappen',
            position: '1',
            points: '350',
          ),
        ],
      );
      FavoriteResultAlertService.apiFactory = () => fake;

      await FavoriteResultAlertService.checkForUpdates(season: '2026');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'favorite_alert_last_check_at',
        DateTime.now()
            .subtract(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
      );

      fake.driverStandings = [
        _buildDriverStanding(
          driverId: 'verstappen',
          position: '1',
          points: '375',
        ),
      ];

      await FavoriteResultAlertService.checkForUpdates(season: '2026');

      expect(
        prefs.getString('favorite_alert_driver_points|2026|verstappen'),
        '375',
      );
    });
  });
}

class _FakeApiService extends ApiService {
  SessionResults? lastRace;
  SessionResults? lastSprint;
  SessionResults? lastQualifying;
  List<DriverStanding> driverStandings;
  List<ConstructorStanding> constructorStandings;

  _FakeApiService({
    this.lastRace,
    this.lastSprint,
    this.lastQualifying,
    this.driverStandings = const [],
    this.constructorStandings = const [],
  });

  @override
  Future<SessionResults?> getLastRaceResults({required String season}) async =>
      lastRace;

  @override
  Future<SessionResults?> getLastSprintResults({
    required String season,
  }) async =>
      lastSprint;

  @override
  Future<SessionResults?> getLastQualifyingResults({
    required String season,
  }) async =>
      lastQualifying;

  @override
  Future<List<DriverStanding>> getDriverStandings({String? season}) async =>
      driverStandings;

  @override
  Future<List<ConstructorStanding>> getConstructorStandings({
    String? season,
  }) async =>
      constructorStandings;
}

SessionResults _buildSession({
  required SessionType type,
  required String round,
  required String raceName,
}) {
  return SessionResults(
    race: Race(
      round: round,
      raceName: raceName,
      date: '2026-05-10',
      time: '13:00:00Z',
      circuitId: 'circuit',
      circuitName: 'Circuit',
      locality: 'Locality',
      country: 'Country',
      practice1: null,
      practice2: null,
      practice3: null,
      qualifying: null,
      sprintQualifying: null,
      sprint: null,
    ),
    results: const [],
    type: type,
  );
}

DriverStanding _buildDriverStanding({
  required String driverId,
  required String position,
  required String points,
}) {
  return DriverStanding(
    position: position,
    points: points,
    wins: '0',
    givenName: 'Max',
    familyName: 'Verstappen',
    teamName: 'Red Bull',
    driverId: driverId,
    constructorId: 'red_bull',
    code: 'VER',
    permanentNumber: '1',
  );
}
