import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/services/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
