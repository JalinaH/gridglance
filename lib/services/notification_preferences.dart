import 'package:shared_preferences/shared_preferences.dart';
import '../models/race.dart';
import 'notification_service.dart';

class NotificationPreferences {
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

  static String _keyForSession({
    required Race race,
    required RaceSession session,
    required String season,
  }) {
    final sessionKey =
        NotificationService.sessionKey(race: race, session: session, season: season);
    return 'notify_$sessionKey';
  }
}
