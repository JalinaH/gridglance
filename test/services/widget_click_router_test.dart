import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/services/widget_click_router.dart';

void main() {
  WidgetClickTarget? parse(String type, {String? targetId, Object? id = 7}) =>
      WidgetClickTarget.fromPayload({
        'type': type,
        'widgetId': '$id',
        'targetId': ?targetId,
      });

  group('WidgetClickTarget.fromPayload', () {
    test('rejects malformed payloads', () {
      expect(WidgetClickTarget.fromPayload(null), isNull);
      expect(WidgetClickTarget.fromPayload({'widgetId': '1'}), isNull);
      expect(parse('driver_standings', id: 'abc'), isNull);
      expect(parse('unknown_widget'), isNull);
    });

    test('standings widgets open the list or a tapped podium entry', () {
      expect(
        parse('driver_standings')!.destination,
        WidgetDestination.driverStandings,
      );
      final driver = parse('driver_standings', targetId: 'max_verstappen')!;
      expect(driver.destination, WidgetDestination.driverDetail);
      expect(driver.targetId, 'max_verstappen');

      expect(
        parse('team_standings')!.destination,
        WidgetDestination.teamStandings,
      );
      final team = parse('team_standings', targetId: 'ferrari')!;
      expect(team.destination, WidgetDestination.teamDetail);
      expect(team.targetId, 'ferrari');
    });

    test('favorite widgets open detail, or the picker when unconfigured', () {
      expect(
        parse('favorite_driver', targetId: 'norris')!.destination,
        WidgetDestination.driverDetail,
      );
      expect(
        parse('favorite_driver', targetId: '  ')!.destination,
        WidgetDestination.favoriteDriverConfig,
      );
      expect(
        parse('favorite_team')!.destination,
        WidgetDestination.favoriteTeamConfig,
      );
      expect(
        parse('favorite_team', targetId: 'mclaren')!.destination,
        WidgetDestination.teamDetail,
      );
    });

    test('gear button always opens the picker for that widget', () {
      final target = parse(
        'favorite_driver_config',
        targetId: 'norris',
        id: 42,
      )!;
      expect(target.destination, WidgetDestination.favoriteDriverConfig);
      expect(target.widgetId, 42);
      expect(
        parse('favorite_team_config')!.destination,
        WidgetDestination.favoriteTeamConfig,
      );
    });

    test('race weekend widget opens the race detail', () {
      expect(parse('race_weekend')!.destination, WidgetDestination.raceDetail);
    });
  });

  group('WidgetClickTarget.fromPayload from iOS', () {
    // AppDelegate.widgetClick sends a native int widgetId (always 0) and only
    // includes targetId when the tap carried one.
    test('accepts the payload shape iOS sends', () {
      final team = WidgetClickTarget.fromPayload({
        'type': 'favorite_team',
        'widgetId': 0,
        'targetId': 'mclaren',
      })!;
      expect(team.destination, WidgetDestination.teamDetail);
      expect(team.targetId, 'mclaren');
      expect(team.widgetId, 0);

      final race = WidgetClickTarget.fromPayload({
        'type': 'race_weekend',
        'widgetId': 0,
      })!;
      expect(race.destination, WidgetDestination.raceDetail);
    });

    test('a podium tap without a target opens the list', () {
      final list = WidgetClickTarget.fromPayload({
        'type': 'team_standings',
        'widgetId': 0,
      })!;
      expect(list.destination, WidgetDestination.teamStandings);
    });
  });
}
