import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static const String _seasonKey = 'selected_season';
  static const String _favoriteDriverIdKey = 'favorite_driver_id';
  static const String _favoriteTeamIdKey = 'favorite_team_id';

  static Future<String?> getSeason() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_seasonKey);
  }

  static Future<void> setSeason(String season) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seasonKey, season);
  }

  static Future<String?> getFavoriteDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_favoriteDriverIdKey);
  }

  static Future<void> setFavoriteDriverId(String? driverId) async {
    final prefs = await SharedPreferences.getInstance();
    if (driverId == null || driverId.isEmpty) {
      await prefs.remove(_favoriteDriverIdKey);
      return;
    }
    await prefs.setString(_favoriteDriverIdKey, driverId);
  }

  static Future<String?> getFavoriteTeamId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_favoriteTeamIdKey);
  }

  static Future<void> setFavoriteTeamId(String? teamId) async {
    final prefs = await SharedPreferences.getInstance();
    if (teamId == null || teamId.isEmpty) {
      await prefs.remove(_favoriteTeamIdKey);
      return;
    }
    await prefs.setString(_favoriteTeamIdKey, teamId);
  }
}
