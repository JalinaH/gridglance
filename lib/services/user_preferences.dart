import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static const String _seasonKey = 'selected_season';
  static const String _seasonSavedYearKey = 'selected_season_saved_year';
  static const String _favoriteDriverIdKey = 'favorite_driver_id';
  static const String _favoriteTeamIdKey = 'favorite_team_id';

  static String? _season;
  static String? _favoriteDriverId;
  static String? _favoriteTeamId;
  static bool _initialized = false;

  /// Clock indirection so tests can simulate a new year.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// Loads stored values into memory once at app boot. Subsequent reads can
  /// use the synchronous getters (`seasonSync`, etc.) instead of awaiting
  /// `SharedPreferences.getInstance()` on every screen `initState`.
  static Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _season = _readSeason(prefs);
    _favoriteDriverId = prefs.getString(_favoriteDriverIdKey);
    _favoriteTeamId = prefs.getString(_favoriteTeamIdKey);
    _initialized = true;
  }

  /// Whether [init] has populated the in-memory cache.
  static bool get isInitialized => _initialized;

  static String? get seasonSync => _season;
  static String? get favoriteDriverIdSync => _favoriteDriverId;
  static String? get favoriteTeamIdSync => _favoriteTeamId;

  static Future<String?> getSeason() async {
    if (_initialized) return _season;
    final prefs = await SharedPreferences.getInstance();
    return _readSeason(prefs);
  }

  static Future<void> setSeason(String season) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seasonKey, season);
    await prefs.setInt(_seasonSavedYearKey, clock().year);
    _season = season;
  }

  /// The season picker is a browsing choice, so it only sticks for the
  /// calendar year it was made in. Once the year rolls over the app falls
  /// back to the current season instead of staying on last year forever.
  /// Selections saved before the year was recorded only survive if they
  /// already match the current year.
  static String? _readSeason(SharedPreferences prefs) {
    final season = prefs.getString(_seasonKey);
    if (season == null || season.isEmpty) {
      return null;
    }
    final currentYear = clock().year;
    final savedYear = prefs.getInt(_seasonSavedYearKey);
    final stillValid = savedYear == null
        ? season == currentYear.toString()
        : savedYear == currentYear;
    return stillValid ? season : null;
  }

  static Future<String?> getFavoriteDriverId() async {
    if (_initialized) return _favoriteDriverId;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_favoriteDriverIdKey);
  }

  static Future<void> setFavoriteDriverId(String? driverId) async {
    final prefs = await SharedPreferences.getInstance();
    if (driverId == null || driverId.isEmpty) {
      await prefs.remove(_favoriteDriverIdKey);
      _favoriteDriverId = null;
      return;
    }
    await prefs.setString(_favoriteDriverIdKey, driverId);
    _favoriteDriverId = driverId;
  }

  static Future<String?> getFavoriteTeamId() async {
    if (_initialized) return _favoriteTeamId;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_favoriteTeamIdKey);
  }

  static Future<void> setFavoriteTeamId(String? teamId) async {
    final prefs = await SharedPreferences.getInstance();
    if (teamId == null || teamId.isEmpty) {
      await prefs.remove(_favoriteTeamIdKey);
      _favoriteTeamId = null;
      return;
    }
    await prefs.setString(_favoriteTeamIdKey, teamId);
    _favoriteTeamId = teamId;
  }

  /// Clears the in-memory cache so a subsequent [init] reloads from disk.
  /// Intended for tests that swap `SharedPreferences.setMockInitialValues`.
  @visibleForTesting
  static void resetForTesting() {
    _season = null;
    clock = DateTime.now;
    _favoriteDriverId = null;
    _favoriteTeamId = null;
    _initialized = false;
  }
}
