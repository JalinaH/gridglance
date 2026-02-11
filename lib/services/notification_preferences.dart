import 'package:shared_preferences/shared_preferences.dart';
import '../models/race.dart';
import 'notification_service.dart';

class NotificationPreferences {
  static const String _scheduledRaceKey = 'scheduled_race';
  static const int defaultLeadTimeMinutes = 15;
  static const List<int> leadTimePresets = [5, 15, 60, 1440];

  static Future<String?> getScheduledRace() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scheduledRaceKey);
  }

  static Future<void> setScheduledRace(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scheduledRaceKey, value);
  }

  static Future<bool> isSessionEnabled({
    required Race race,
    required RaceSession session,
    required String season,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyForSession(race: race, session: session, season: season);
    return prefs.getBool(key) ?? false;
  }

  static Future<void> setSessionEnabled({
    required Race race,
    required RaceSession session,
    required String season,
    required bool value,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyForSession(race: race, session: session, season: season);
    await prefs.setBool(key, value);
  }

  static Future<int> getSessionLeadTimeMinutes({
    required Race race,
    required RaceSession session,
    required String season,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _leadTimeKeyForSession(
      race: race,
      session: session,
      season: season,
    );
    final stored = prefs.getInt(key);
    if (stored == null || !leadTimePresets.contains(stored)) {
      return defaultLeadTimeMinutes;
    }
    return stored;
  }

  static Future<void> setSessionLeadTimeMinutes({
    required Race race,
    required RaceSession session,
    required String season,
    required int minutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _leadTimeKeyForSession(
      race: race,
      session: session,
      season: season,
    );
    await prefs.setInt(key, minutes);
  }

  static Future<bool> isWeekendDigestEnabled({
    required Race race,
    required String season,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _weekendDigestKey(race: race, season: season);
    return prefs.getBool(key) ?? false;
  }

  static Future<void> setWeekendDigestEnabled({
    required Race race,
    required String season,
    required bool value,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _weekendDigestKey(race: race, season: season);
    await prefs.setBool(key, value);
  }

  static String _keyForSession({
    required Race race,
    required RaceSession session,
    required String season,
  }) {
    final sessionKey = NotificationService.sessionKey(
      race: race,
      session: session,
      season: season,
    );
    return 'notify_$sessionKey';
  }

  static String _leadTimeKeyForSession({
    required Race race,
    required RaceSession session,
    required String season,
  }) {
    final sessionKey = NotificationService.sessionKey(
      race: race,
      session: session,
      season: season,
    );
    return 'notify_lead_$sessionKey';
  }

  static String _weekendDigestKey({
    required Race race,
    required String season,
  }) {
    final digestKey = NotificationService.weekendDigestKey(
      race: race,
      season: season,
    );
    return 'notify_digest_$digestKey';
  }
}
