import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

