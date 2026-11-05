import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/services/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(UserPreferences.resetForTesting);

  group('UserPreferences.season', () {
    test('returns null when no season is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final result = await UserPreferences.getSeason();
      expect(result, isNull);
    });

    test('stores and retrieves a season', () async {
      SharedPreferences.setMockInitialValues({});
      await UserPreferences.setSeason('2026');
      final result = await UserPreferences.getSeason();
      expect(result, '2026');
    });

    test('overwrites a previously stored season', () async {
      SharedPreferences.setMockInitialValues({'selected_season': '2025'});
      await UserPreferences.setSeason('2026');
      final result = await UserPreferences.getSeason();
      expect(result, '2026');
    });
  });

  group('UserPreferences.season year rollover', () {
    test('keeps a past season picked during the current year', () async {
      SharedPreferences.setMockInitialValues({});
      UserPreferences.clock = () => DateTime(2026, 6, 1);
      await UserPreferences.setSeason('2023');

      expect(await UserPreferences.getSeason(), '2023');
    });

    test('drops the selection once the year changes', () async {
      SharedPreferences.setMockInitialValues({});
      UserPreferences.clock = () => DateTime(2026, 6, 1);
      await UserPreferences.setSeason('2026');

      UserPreferences.clock = () => DateTime(2027, 1, 2);
      expect(await UserPreferences.getSeason(), isNull);
    });

    test('init applies the same rollover rule', () async {
      SharedPreferences.setMockInitialValues({
        'selected_season': '2025',
        'selected_season_saved_year': 2025,
      });
      UserPreferences.clock = () => DateTime(2026, 3, 1);

      await UserPreferences.init();

      expect(UserPreferences.seasonSync, isNull);
    });

    test(
      'legacy selection without a saved year survives only if current',
      () async {
        UserPreferences.clock = () => DateTime(2026, 3, 1);

        SharedPreferences.setMockInitialValues({'selected_season': '2026'});
        expect(await UserPreferences.getSeason(), '2026');

        SharedPreferences.setMockInitialValues({'selected_season': '2024'});
        expect(await UserPreferences.getSeason(), isNull);
      },
    );
  });

  group('UserPreferences.favoriteDriverId', () {
    test('returns null when no driver is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final result = await UserPreferences.getFavoriteDriverId();
      expect(result, isNull);
    });

    test('stores and retrieves a driver id', () async {
      SharedPreferences.setMockInitialValues({});
      await UserPreferences.setFavoriteDriverId('verstappen');
      final result = await UserPreferences.getFavoriteDriverId();
      expect(result, 'verstappen');
    });

    test('removes driver when set to null', () async {
      SharedPreferences.setMockInitialValues({
        'favorite_driver_id': 'hamilton',
      });
      await UserPreferences.setFavoriteDriverId(null);
      final result = await UserPreferences.getFavoriteDriverId();
      expect(result, isNull);
    });

    test('removes driver when set to empty string', () async {
      SharedPreferences.setMockInitialValues({'favorite_driver_id': 'norris'});
      await UserPreferences.setFavoriteDriverId('');
      final result = await UserPreferences.getFavoriteDriverId();
      expect(result, isNull);
    });
  });

  group('UserPreferences.favoriteTeamId', () {
    test('returns null when no team is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final result = await UserPreferences.getFavoriteTeamId();
      expect(result, isNull);
    });

    test('stores and retrieves a team id', () async {
      SharedPreferences.setMockInitialValues({});
      await UserPreferences.setFavoriteTeamId('ferrari');
      final result = await UserPreferences.getFavoriteTeamId();
      expect(result, 'ferrari');
    });

    test('removes team when set to null', () async {
      SharedPreferences.setMockInitialValues({'favorite_team_id': 'mclaren'});
      await UserPreferences.setFavoriteTeamId(null);
      final result = await UserPreferences.getFavoriteTeamId();
      expect(result, isNull);
    });

    test('removes team when set to empty string', () async {
      SharedPreferences.setMockInitialValues({'favorite_team_id': 'mercedes'});
      await UserPreferences.setFavoriteTeamId('');
      final result = await UserPreferences.getFavoriteTeamId();
      expect(result, isNull);
    });
  });
}
