import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_service.dart';
import '../models/constructor_standing.dart';
import '../models/driver_standing.dart';
import '../models/session_results.dart';
import 'notification_preferences.dart';
import 'notification_service.dart';
import 'user_preferences.dart';

class FavoriteResultAlertService {
  static const Duration _minimumCheckInterval = Duration(minutes: 2);
  static const String _lastCheckAtKey = 'favorite_alert_last_check_at';
  static const String _sessionSeededPrefix = 'favorite_alert_session_seeded';
  static const String _standingsSeededPrefix =
      'favorite_alert_standings_seeded';
  static bool _checking = false;

  static Future<void> checkForUpdates({String? season}) async {
    if (_checking) {
      return;
    }
    _checking = true;
    try {
      final sessionFinishedEnabled =
          await NotificationPreferences.isFavoriteSessionFinishedEnabled();
      final standingsUpdateEnabled =
          await NotificationPreferences.isFavoritePositionPointsEnabled();
      if (!sessionFinishedEnabled && !standingsUpdateEnabled) {
        return;
      }

      final favoriteDriverId = await UserPreferences.getFavoriteDriverId();
      final favoriteTeamId = await UserPreferences.getFavoriteTeamId();
      final hasFavoriteDriver =
          favoriteDriverId != null && favoriteDriverId.isNotEmpty;
      final hasFavoriteTeam =
          favoriteTeamId != null && favoriteTeamId.isNotEmpty;
      if (!hasFavoriteDriver && !hasFavoriteTeam) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      if (!await _shouldRunNow(prefs)) {
        return;
      }

      final selectedSeason =
          season ??
          await UserPreferences.getSeason() ??
          DateTime.now().year.toString();
      final api = ApiService();

      final values = await Future.wait<Object?>([
        sessionFinishedEnabled
            ? _safe<SessionResults?>(
                api.getLastRaceResults(season: selectedSeason),
              )
            : Future.value(null),
        sessionFinishedEnabled
            ? _safe<SessionResults?>(
                api.getLastSprintResults(season: selectedSeason),
              )
            : Future.value(null),
        sessionFinishedEnabled
            ? _safe<SessionResults?>(
                api.getLastQualifyingResults(season: selectedSeason),
              )
            : Future.value(null),
        standingsUpdateEnabled
            ? _safe<List<DriverStanding>>(
                api.getDriverStandings(season: selectedSeason),
              )
            : Future.value(null),
        standingsUpdateEnabled
            ? _safe<List<ConstructorStanding>>(
                api.getConstructorStandings(season: selectedSeason),
              )
            : Future.value(null),
      ]);

      final raceResults = values[0] as SessionResults?;
      final sprintResults = values[1] as SessionResults?;
      final qualifyingResults = values[2] as SessionResults?;
      final driverStandings = values[3] as List<DriverStanding>?;
      final teamStandings = values[4] as List<ConstructorStanding>?;

      if (sessionFinishedEnabled) {
        final sessionSeededKey = _sessionSeededKey(selectedSeason);
        final sessionSeeded = prefs.getBool(sessionSeededKey) ?? false;
        if (!sessionSeeded) {
          await _storeSessionBaseline(
            prefs: prefs,
            season: selectedSeason,
            raceResults: raceResults,
            sprintResults: sprintResults,
            qualifyingResults: qualifyingResults,
          );
          await prefs.setBool(sessionSeededKey, true);
        } else {
          await _processSessionFinishedAlerts(
            prefs: prefs,
            season: selectedSeason,
            session: raceResults,
            favoriteDriverId: favoriteDriverId,
            favoriteTeamId: favoriteTeamId,
          );
          await _processSessionFinishedAlerts(
            prefs: prefs,
            season: selectedSeason,
            session: sprintResults,
            favoriteDriverId: favoriteDriverId,
            favoriteTeamId: favoriteTeamId,
          );
          await _processSessionFinishedAlerts(
            prefs: prefs,
            season: selectedSeason,
            session: qualifyingResults,
            favoriteDriverId: favoriteDriverId,
            favoriteTeamId: favoriteTeamId,
          );
        }
      }

      if (standingsUpdateEnabled) {
        final standingsSeededKey = _standingsSeededKey(selectedSeason);
        final standingsSeeded = prefs.getBool(standingsSeededKey) ?? false;
        if (!standingsSeeded) {
          await _storeStandingsBaseline(
            prefs: prefs,
            season: selectedSeason,
            favoriteDriverId: favoriteDriverId,
            favoriteTeamId: favoriteTeamId,
            driverStandings: driverStandings,
            teamStandings: teamStandings,
          );
          await prefs.setBool(standingsSeededKey, true);
        } else {
          await _processStandingsUpdates(
            prefs: prefs,
            season: selectedSeason,
            favoriteDriverId: favoriteDriverId,
            favoriteTeamId: favoriteTeamId,
            driverStandings: driverStandings,
            teamStandings: teamStandings,
          );
        }
      }
    } finally {
      _checking = false;
    }
  }

  static Future<T?> _safe<T>(Future<T> future) async {
    try {
      return await future;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _shouldRunNow(SharedPreferences prefs) async {
    final now = DateTime.now();
    final lastEpoch = prefs.getInt(_lastCheckAtKey);
    if (lastEpoch != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastEpoch);
      if (now.difference(last) < _minimumCheckInterval) {
        return false;
      }
    }
    await prefs.setInt(_lastCheckAtKey, now.millisecondsSinceEpoch);
    return true;
  }

  static String _sessionSeededKey(String season) {
    return '$_sessionSeededPrefix|$season';
  }

  static String _standingsSeededKey(String season) {
    return '$_standingsSeededPrefix|$season';
  }

  static String _lastSessionKey({
    required String season,
    required SessionType type,
  }) {
    return 'favorite_alert_last_session|$season|${type.name}';
  }

  static String _sessionEventKey(SessionResults session) {
    final timestamp =
        _sessionStartDateTime(session)?.toUtc().toIso8601String() ??
        '${session.race.date}|${session.race.time ?? ''}';
    return [
      session.type.name,
      session.race.round,
      session.race.raceName,
      timestamp,
    ].join('|');
  }

  static DateTime? _sessionStartDateTime(SessionResults session) {
    switch (session.type) {
      case SessionType.race:
        return session.race.startDateTime;
      case SessionType.qualifying:
        return session.race.qualifying?.startDateTime;
      case SessionType.sprint:
        return session.race.sprint?.startDateTime;
    }
  }

  static Future<void> _storeSessionBaseline({
    required SharedPreferences prefs,
    required String season,
    required SessionResults? raceResults,
    required SessionResults? sprintResults,
    required SessionResults? qualifyingResults,
  }) async {
    if (raceResults != null) {
      await prefs.setString(
        _lastSessionKey(season: season, type: SessionType.race),
        _sessionEventKey(raceResults),
      );
    }
    if (sprintResults != null) {
      await prefs.setString(
        _lastSessionKey(season: season, type: SessionType.sprint),
        _sessionEventKey(sprintResults),
      );
    }
    if (qualifyingResults != null) {
      await prefs.setString(
        _lastSessionKey(season: season, type: SessionType.qualifying),
        _sessionEventKey(qualifyingResults),
      );
    }
  }

  static Future<void> _processSessionFinishedAlerts({
    required SharedPreferences prefs,
    required String season,
    required SessionResults? session,
    required String? favoriteDriverId,
    required String? favoriteTeamId,
  }) async {
    if (session == null) {
      return;
    }
    final eventKey = _sessionEventKey(session);
    final storageKey = _lastSessionKey(season: season, type: session.type);
    final previous = prefs.getString(storageKey);
    if (previous == eventKey) {
      return;
    }
    await prefs.setString(storageKey, eventKey);

    final sessionLabel = _sessionLabel(session.type);
    final title = '${session.race.raceName} • $sessionLabel finished';

    if (favoriteDriverId != null && favoriteDriverId.isNotEmpty) {
      final driverBody = _driverSessionBody(
        session: session,
        favoriteDriverId: favoriteDriverId,
      );
      await NotificationService.showFavoriteResultNotification(
        season: season,
        entityType: 'driver',
        entityId: favoriteDriverId,
        category: 'session_finished',
        eventKey: eventKey,
        title: title,
        body: driverBody,
      );
    }

    if (favoriteTeamId != null && favoriteTeamId.isNotEmpty) {
      final teamBody = _teamSessionBody(
        session: session,
        favoriteTeamId: favoriteTeamId,
      );
      await NotificationService.showFavoriteResultNotification(
        season: season,
        entityType: 'team',
        entityId: favoriteTeamId,
        category: 'session_finished',
        eventKey: eventKey,
        title: title,
        body: teamBody,
      );
    }
  }

  static String _driverSessionBody({
    required SessionResults session,
    required String favoriteDriverId,
  }) {
    ResultEntry? match;
    for (final result in session.results) {
      if (result.driverId == favoriteDriverId) {
        match = result;
        break;
      }
    }
    if (match == null) {
      return 'Your favorite driver has a new session result.';
    }
    final position = _positionLabel(match.position);
    final pointsSuffix = _pointsSuffix(match.points, includePlus: true);
    if (pointsSuffix.isEmpty) {
      return '${match.driverName} finished $position.';
    }
    return '${match.driverName} finished $position$pointsSuffix.';
  }

  static String _teamSessionBody({
    required SessionResults session,
    required String favoriteTeamId,
  }) {
    final teamEntries = session.results
        .where((result) => result.constructorId == favoriteTeamId)
        .toList();
    if (teamEntries.isEmpty) {
      return 'Your favorite team has a new session result.';
    }
    final positions = teamEntries
        .map((entry) => int.tryParse(entry.position))
        .whereType<int>()
        .toList();
    final bestPosition = positions.isEmpty
        ? null
        : positions.reduce((best, next) => next < best ? next : best);
    final totalPoints = teamEntries.fold<double>(
      0,
      (sum, entry) => sum + (double.tryParse(entry.points) ?? 0),
    );
    final teamName = teamEntries.first.teamName;
    if (bestPosition == null) {
      final pointsSuffix = _pointsSuffix('$totalPoints', includePlus: true);
      return pointsSuffix.isEmpty
          ? '$teamName session result is now available.'
          : '$teamName$pointsSuffix.';
    }
    final pointsSuffix = _pointsSuffix('$totalPoints', includePlus: true);
    if (pointsSuffix.isEmpty) {
      return '$teamName best finish: P$bestPosition.';
    }
    return '$teamName best finish: P$bestPosition$pointsSuffix.';
  }

  static String _positionLabel(String raw) {
    final asInt = int.tryParse(raw);
    if (asInt == null || asInt <= 0) {
      return raw.isEmpty ? 'result pending' : raw;
    }
    return 'P$asInt';
  }

  static String _pointsSuffix(String raw, {required bool includePlus}) {
    final points = double.tryParse(raw) ?? 0;
    if (points <= 0) {
      return '';
    }
    final formatted = points == points.roundToDouble()
        ? points.toInt().toString()
        : points.toStringAsFixed(1);
    return includePlus ? ' • +$formatted pts' : ' • $formatted pts';
  }

  static String _sessionLabel(SessionType type) {
    switch (type) {
      case SessionType.race:
        return 'Race';
      case SessionType.qualifying:
        return 'Qualifying';
      case SessionType.sprint:
        return 'Sprint';
    }
  }

  static String _driverPositionKey({
    required String season,
    required String driverId,
  }) {
    return 'favorite_alert_driver_position|$season|$driverId';
  }

  static String _driverPointsKey({
    required String season,
    required String driverId,
  }) {
    return 'favorite_alert_driver_points|$season|$driverId';
  }

  static String _teamPositionKey({
    required String season,
    required String teamId,
  }) {
    return 'favorite_alert_team_position|$season|$teamId';
  }

  static String _teamPointsKey({
    required String season,
    required String teamId,
  }) {
    return 'favorite_alert_team_points|$season|$teamId';
  }

  static Future<void> _storeStandingsBaseline({
    required SharedPreferences prefs,
    required String season,
    required String? favoriteDriverId,
    required String? favoriteTeamId,
    required List<DriverStanding>? driverStandings,
    required List<ConstructorStanding>? teamStandings,
  }) async {
    if (favoriteDriverId != null &&
        favoriteDriverId.isNotEmpty &&
        driverStandings != null) {
      for (final standing in driverStandings) {
        if (standing.driverId == favoriteDriverId) {
          await prefs.setString(
            _driverPositionKey(season: season, driverId: favoriteDriverId),
            standing.position,
          );
          await prefs.setString(
            _driverPointsKey(season: season, driverId: favoriteDriverId),
            standing.points,
          );
          break;
        }
      }
    }

    if (favoriteTeamId != null &&
        favoriteTeamId.isNotEmpty &&
        teamStandings != null) {
      for (final standing in teamStandings) {
        if (standing.constructorId == favoriteTeamId) {
          await prefs.setString(
            _teamPositionKey(season: season, teamId: favoriteTeamId),
            standing.position,
          );
          await prefs.setString(
            _teamPointsKey(season: season, teamId: favoriteTeamId),
            standing.points,
          );
          break;
        }
      }
    }
  }

  static Future<void> _processStandingsUpdates({
    required SharedPreferences prefs,
    required String season,
    required String? favoriteDriverId,
    required String? favoriteTeamId,
    required List<DriverStanding>? driverStandings,
    required List<ConstructorStanding>? teamStandings,
  }) async {
    if (favoriteDriverId != null &&
        favoriteDriverId.isNotEmpty &&
        driverStandings != null) {
      DriverStanding? current;
      for (final standing in driverStandings) {
        if (standing.driverId == favoriteDriverId) {
          current = standing;
          break;
        }
      }
      if (current != null) {
        final positionKey = _driverPositionKey(
          season: season,
          driverId: favoriteDriverId,
        );
        final pointsKey = _driverPointsKey(
          season: season,
          driverId: favoriteDriverId,
        );
        final previousPosition = prefs.getString(positionKey);
        final previousPoints = prefs.getString(pointsKey);
        final changed =
            previousPosition != null &&
            previousPoints != null &&
            (previousPosition != current.position ||
                previousPoints != current.points);
        if (changed) {
          final driverName = '${current.givenName} ${current.familyName}'
              .trim();
          await NotificationService.showFavoriteResultNotification(
            season: season,
            entityType: 'driver',
            entityId: favoriteDriverId,
            category: 'position_points',
            eventKey: '$season|driver|${current.position}|${current.points}',
            title: 'Favorite driver update',
            body:
                '$driverName now P${current.position} with ${current.points} pts (was P$previousPosition, $previousPoints pts).',
          );
        }
        await prefs.setString(positionKey, current.position);
        await prefs.setString(pointsKey, current.points);
      }
    }

    if (favoriteTeamId != null &&
        favoriteTeamId.isNotEmpty &&
        teamStandings != null) {
      ConstructorStanding? current;
      for (final standing in teamStandings) {
        if (standing.constructorId == favoriteTeamId) {
          current = standing;
          break;
        }
      }
      if (current != null) {
        final positionKey = _teamPositionKey(
          season: season,
          teamId: favoriteTeamId,
        );
        final pointsKey = _teamPointsKey(
          season: season,
          teamId: favoriteTeamId,
        );
        final previousPosition = prefs.getString(positionKey);
        final previousPoints = prefs.getString(pointsKey);
        final changed =
            previousPosition != null &&
            previousPoints != null &&
            (previousPosition != current.position ||
                previousPoints != current.points);
        if (changed) {
          await NotificationService.showFavoriteResultNotification(
            season: season,
            entityType: 'team',
            entityId: favoriteTeamId,
            category: 'position_points',
            eventKey: '$season|team|${current.position}|${current.points}',
            title: 'Favorite team update',
            body:
                '${current.teamName} now P${current.position} with ${current.points} pts (was P$previousPosition, $previousPoints pts).',
          );
        }
        await prefs.setString(positionKey, current.position);
        await prefs.setString(pointsKey, current.points);
      }
    }
  }
}
