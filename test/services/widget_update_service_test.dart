import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/models/race.dart';
import 'package:gridglance/services/widget_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The service writes per-widget fields through this channel; the Android
  // side persists them via DeviceProtectedStorage, but in tests we just
  // capture the calls.
  const dpsChannel = MethodChannel('gridglance/dps');
  // The home_widget plugin's main channel handles `updateWidget` /
  // `setAppGroupId`; we swallow these so the refresh call doesn't fail.
  const homeWidgetChannel = MethodChannel('home_widget');

  late List<MethodCall> dpsCalls;

  Map<String, String> collectWrites() {
    return {
      for (final call in dpsCalls.where((c) => c.method == 'saveWidgetData'))
        call.arguments['id'] as String: call.arguments['data'] as String,
    };
  }

  setUp(() {
    dpsCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(dpsChannel, (call) async {
          dpsCalls.add(call);
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (_) async => true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(dpsChannel, null);
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

  group('updateNextSessionWidget', () {
    test(
      'writes "no upcoming session" placeholders when schedule is empty',
      () async {
        await WidgetUpdateService.updateNextSessionWidget(
          const [],
          season: '2026',
        );

        final w = collectWrites();
        expect(w['next_session_widget_title'], 'Next Session');
        expect(w['next_session_widget_name'], 'No upcoming session');
        expect(w['next_session_widget_race'], 'Schedule unavailable');
      },
    );
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
