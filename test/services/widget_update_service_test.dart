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

  group('updateNextRaceCountdown', () {
    test('writes placeholder fields when the race is null', () async {
      await WidgetUpdateService.updateNextRaceCountdown(null, season: '2026');

      final w = collectWrites();
      expect(w['next_race_widget_title'], 'Next Race');
      expect(w['next_race_widget_season'], '2026');
      expect(w['next_race_widget_name'], 'No upcoming race');
      expect(w['next_race_widget_location'], 'Season complete');
      expect(w['next_race_widget_days'], '--');
      expect(w['next_race_widget_round'], '');
    });

    test(
      'writes round, name, and circuit fields when a race is provided',
      () async {
        final race = _buildRace(
          round: '5',
          raceName: 'Spanish GP',
          circuitName: 'Circuit de Barcelona-Catalunya',
          date: '2099-01-01',
          time: '13:00:00Z',
        );

        await WidgetUpdateService.updateNextRaceCountdown(race, season: '2026');

        final w = collectWrites();
        expect(w['next_race_widget_round'], 'R5');
        expect(w['next_race_widget_name'], 'Spanish GP');
        expect(w['next_race_widget_circuit'], 'Circuit de Barcelona-Catalunya');
        // Far-future date so the segmented countdown is positive.
        final days = int.parse(w['next_race_widget_days']!);
        expect(days, greaterThan(0));
      },
    );

    test(
      'falls back to "Time TBA" when the race has no parsable time',
      () async {
        final race = _buildRace(
          round: '1',
          raceName: 'Pre-season',
          circuitName: 'TBD',
          date: '',
          time: null,
        );

        await WidgetUpdateService.updateNextRaceCountdown(race, season: '2026');

        final w = collectWrites();
        expect(w['next_race_widget_start'], 'Time TBA');
      },
    );
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

  group('transparency setters', () {
    test(
      'setNextRaceWidgetTransparent writes the boolean as a string',
      () async {
        await WidgetUpdateService.setNextRaceWidgetTransparent(true);
        expect(collectWrites()['next_race_widget_transparent'], 'true');

        await WidgetUpdateService.setNextRaceWidgetTransparent(false);
        // The latest write wins in the map; verify the false value landed.
        expect(collectWrites()['next_race_widget_transparent'], 'false');
      },
    );

    test(
      'setRaceWeekendWidgetTransparent writes the boolean as a string',
      () async {
        await WidgetUpdateService.setRaceWeekendWidgetTransparent(true);
        expect(collectWrites()['race_weekend_widget_transparent'], 'true');
      },
    );
  });
}

Race _buildRace({
  required String round,
  required String raceName,
  required String circuitName,
  required String date,
  required String? time,
}) {
  return Race(
    round: round,
    raceName: raceName,
    date: date,
    time: time,
    circuitId: 'circuit',
    circuitName: circuitName,
    locality: 'Locality',
    country: 'Country',
    practice1: null,
    practice2: null,
    practice3: null,
    qualifying: null,
    sprintQualifying: null,
    sprint: null,
  );
}
