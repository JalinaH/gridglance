import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/data/api_service.dart';
import 'package:gridglance/models/constructor_standing.dart';
import 'package:gridglance/models/driver_standing.dart';
import 'package:gridglance/models/race.dart';
import 'package:gridglance/services/widget_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Widget data and reloads share home_widget's engine-registered channel.
  const homeWidgetChannel = MethodChannel('home_widget');

  late List<MethodCall> homeWidgetCalls;
  late bool pluginOperationSucceeds;

  Map<String, String> collectWrites() {
    return {
      for (final call in homeWidgetCalls.where(
        (c) => c.method == 'saveWidgetData',
      ))
        call.arguments['id'] as String: call.arguments['data'] as String,
    };
  }

  setUp(() {
    homeWidgetCalls = [];
    pluginOperationSucceeds = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (call) async {
          homeWidgetCalls.add(call);
          if (call.method == 'getWidgetData') {
            return call.arguments['defaultValue'];
          }
          return pluginOperationSucceeds;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, null);
  });

  group('updateTeamStandings', () {
    test('writes "TBD" placeholders when no standings are available', () async {
      await WidgetUpdateService.updateTeamStandings(const [], season: '2026');

      final w = collectWrites();
      expect(w['team_widget_title'], 'Team Standings');
      expect(w['team_widget_subtitle'], 'Standings coming soon');
      expect(w['team_widget_season'], '2026');
      for (final idx in [1, 2, 3]) {
        expect(w['team_${idx}_name'], 'TBD');
        expect(w['team_${idx}_pts'], '0');
      }
    });
  });

  group('updateRaceWeekend', () {
    test(
      'ignores a stale completed nextRace and writes next schedule race',
      () async {
        final now = DateTime.now().toUtc();
        final completed = _race(
          round: '1',
          name: 'Completed Grand Prix',
          start: now.subtract(const Duration(days: 2)),
        );
        final next = _race(
          round: '2',
          name: 'Next Grand Prix',
          start: now.add(const Duration(days: 5)),
        );

        await WidgetUpdateService.updateRaceWeekend(
          [completed, next],
          nextRace: completed,
          season: '2026',
        );

        final w = collectWrites();
        expect(w['race_weekend_widget_name'], 'Next Grand Prix');
        expect(w['race_weekend_widget_round'], 'R2');
      },
    );

    test(
      'keeps the current weekend during the post-race grace window',
      () async {
        final now = DateTime.now().toUtc();
        final current = _race(
          round: '1',
          name: 'Current Grand Prix',
          start: now.subtract(const Duration(hours: 2)),
        );
        final next = _race(
          round: '2',
          name: 'Next Grand Prix',
          start: now.add(const Duration(days: 5)),
        );

        await WidgetUpdateService.updateRaceWeekend([
          current,
          next,
        ], season: '2026');

        final w = collectWrites();
        expect(w['race_weekend_widget_name'], 'Current Grand Prix');
        expect(w['race_weekend_widget_round'], 'R1');
        expect(w['race_weekend_widget_countdown'], 'Weekend in progress');
      },
    );
  });

  group('transparency setters', () {
    test(
      'setRaceWeekendWidgetTransparent writes the boolean as a string',
      () async {
        await WidgetUpdateService.setRaceWeekendWidgetTransparent(true);
        expect(collectWrites()['race_weekend_widget_transparent'], 'true');
      },
    );
  });

  group('refreshAllWidgets', () {
    test('reports fetch, persistence, and reload success', () async {
      final result = await WidgetUpdateService.refreshAllWidgets(
        apiService: _FakeApiService(),
      );

      expect(result.succeeded, isTrue);
      expect(result.failures, isEmpty);
      expect(
        result.steps
            .where((step) => step.phase == WidgetRefreshPhase.fetch)
            .map((step) => step.dataset),
        containsAll(['driverStandings', 'teamStandings', 'raceSchedule']),
      );
      expect(
        result.steps
            .where((step) => step.phase == WidgetRefreshPhase.persist)
            .map((step) => step.dataset),
        containsAll([
          'driverStandings',
          'favoriteDrivers',
          'teamStandings',
          'favoriteTeams',
          'raceWeekend',
        ]),
      );
      expect(
        result.steps
            .where((step) => step.phase == WidgetRefreshPhase.reload)
            .every((step) => step.succeeded),
        isTrue,
      );
    });

    test('does not report success when a required fetch fails', () async {
      final result = await WidgetUpdateService.refreshAllWidgets(
        apiService: _FakeApiService(
          driverFailure: StateError('driver endpoint unavailable'),
        ),
      );

      expect(result.succeeded, isFalse);
      expect(
        result.failures.any(
          (step) =>
              step.dataset == 'driverStandings' &&
              step.phase == WidgetRefreshPhase.fetch,
        ),
        isTrue,
      );
      expect(
        result.failures.any(
          (step) =>
              step.dataset == 'favoriteDrivers' &&
              step.phase == WidgetRefreshPhase.persist,
        ),
        isTrue,
      );
    });

    test('does not report success when widget persistence fails', () async {
      pluginOperationSucceeds = false;

      final result = await WidgetUpdateService.refreshAllWidgets(
        apiService: _FakeApiService(),
      );

      expect(result.succeeded, isFalse);
      expect(
        result.failures.any(
          (step) =>
              step.phase == WidgetRefreshPhase.persist &&
              step.error.toString().contains('returned false'),
        ),
        isTrue,
      );
      expect(
        result.failures.any(
          (step) =>
              step.phase == WidgetRefreshPhase.reload &&
              step.error.toString().contains('persistence failed'),
        ),
        isTrue,
      );
    });
  });

  group('sortSessionsChronologically', () {
    test('orders sprint weekend sessions by start time', () {
      final sessions = [
        RaceSession(
          name: 'Free Practice 1',
          date: '2026-11-06',
          time: '14:30:00Z',
        ),
        RaceSession(name: 'Qualifying', date: '2026-11-07', time: '18:00:00Z'),
        RaceSession(
          name: 'Sprint Qualifying',
          date: '2026-11-06',
          time: '18:30:00Z',
        ),
        RaceSession(name: 'Sprint', date: '2026-11-07', time: '14:00:00Z'),
        RaceSession(name: 'Race', date: '2026-11-08', time: '17:00:00Z'),
      ];

      final sorted = WidgetUpdateService.sortSessionsChronologically(sessions);

      expect(sorted.map((s) => s.name), [
        'Free Practice 1',
        'Sprint Qualifying',
        'Sprint',
        'Qualifying',
        'Race',
      ]);
    });

    test('keeps untimed sessions after timed ones in original order', () {
      final sessions = [
        RaceSession(name: 'A', date: '', time: null),
        RaceSession(name: 'B', date: '2026-11-07', time: '10:00:00Z'),
        RaceSession(name: 'C', date: '', time: null),
        RaceSession(name: 'D', date: '2026-11-06', time: '10:00:00Z'),
      ];

      final sorted = WidgetUpdateService.sortSessionsChronologically(sessions);

      expect(sorted.map((s) => s.name), ['D', 'B', 'A', 'C']);
    });
  });
}

class _FakeApiService extends ApiService {
  final Object? driverFailure;

  _FakeApiService({this.driverFailure});

  @override
  Future<List<DriverStanding>> getDriverStandings({String? season}) async {
    final failure = driverFailure;
    if (failure != null) {
      throw failure;
    }
    return const [];
  }

  @override
  Future<List<ConstructorStanding>> getConstructorStandings({
    String? season,
  }) async {
    return const [];
  }

  @override
  Future<List<Race>> getRaceSchedule({String? season}) async {
    return const [];
  }

  @override
  Future<Race?> getNextRace({String? season}) async {
    return null;
  }
}

Race _race({
  required String round,
  required String name,
  required DateTime start,
}) {
  final utc = start.toUtc();
  return Race(
    round: round,
    raceName: name,
    date: _date(utc),
    time: _time(utc),
    circuitId: 'test_circuit',
    circuitName: 'Test Circuit',
    locality: 'Test City',
    country: 'Test Country',
    practice1: null,
    practice2: null,
    practice3: null,
    qualifying: null,
    sprintQualifying: null,
    sprint: null,
  );
}

String _date(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _time(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$hour:$minute:${second}Z';
}
