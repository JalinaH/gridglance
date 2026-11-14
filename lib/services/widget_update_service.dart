import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';

import '../data/api_service.dart';
import '../models/constructor_standing.dart';
import '../models/driver_standing.dart';
import '../models/race.dart';
import '../utils/team_colors.dart';
import 'crash_reporting.dart';
import 'f1_image_service.dart';

enum WidgetRefreshPhase { fetch, persist, reload }

@immutable
class WidgetRefreshStepResult {
  final String dataset;
  final WidgetRefreshPhase phase;
  final bool succeeded;
  final bool required;
  final Object? error;
  final StackTrace? stackTrace;

  const WidgetRefreshStepResult({
    required this.dataset,
    required this.phase,
    required this.succeeded,
    this.required = true,
    this.error,
    this.stackTrace,
  });
}

@immutable
class WidgetRefreshResult {
  final List<WidgetRefreshStepResult> steps;

  const WidgetRefreshResult(this.steps);

  bool get succeeded =>
      steps.where((step) => step.required).every((step) => step.succeeded);

  List<WidgetRefreshStepResult> get failures =>
      steps.where((step) => !step.succeeded).toList(growable: false);

  String get failureSummary => failures
      .map((step) => '${step.dataset}.${step.phase.name}: ${step.error}')
      .join('; ');
}

class WidgetRefreshException implements Exception {
  final WidgetRefreshResult result;

  const WidgetRefreshException(this.result);

  @override
  String toString() => 'Widget refresh failed: ${result.failureSummary}';
}

class WidgetUpdateService {
  static const String androidDriverWidgetProvider =
      'DriverStandingsWidgetProvider';
  static const String androidQualifiedDriverWidgetProvider =
      'com.gridglance.app.DriverStandingsWidgetProvider';
  static const String androidTeamWidgetProvider = 'TeamStandingsWidgetProvider';
  static const String androidQualifiedTeamWidgetProvider =
      'com.gridglance.app.TeamStandingsWidgetProvider';
  static const String androidFavoriteDriverWidgetProvider =
      'FavoriteDriverWidgetProvider';
  static const String androidQualifiedFavoriteDriverWidgetProvider =
      'com.gridglance.app.FavoriteDriverWidgetProvider';
  static const String androidFavoriteTeamWidgetProvider =
      'FavoriteTeamWidgetProvider';
  static const String androidQualifiedFavoriteTeamWidgetProvider =
      'com.gridglance.app.FavoriteTeamWidgetProvider';
  static const String androidRaceWeekendWidgetProvider =
      'RaceWeekendWidgetProvider';
  static const String androidQualifiedRaceWeekendWidgetProvider =
      'com.gridglance.app.RaceWeekendWidgetProvider';
  static const String iOSRaceWeekendWidgetKind = 'GridGlanceRaceWeekendWidget';
  static const String iOSAppGroupId = 'group.com.gridglance.app';
  static const String iOSDriverWidgetKind = 'GridGlanceDriverStandingsWidget';
  static const String iOSTeamWidgetKind = 'GridGlanceTeamStandingsWidget';
  static const String iOSFavoriteDriverWidgetKind =
      'GridGlanceFavoriteDriverWidget';
  static const String iOSFavoriteTeamWidgetKind =
      'GridGlanceFavoriteTeamWidget';
  static const Duration defaultRefreshInterval = Duration(minutes: 30);

  /// Widget images download inside background tasks (iOS allows ~30s in
  /// total), so a stuck request must not consume the whole budget.
  static const Duration _imageDownloadTimeout = Duration(seconds: 10);
  static const Duration _raceWeekendCompletionGrace = Duration(hours: 4);
  static Timer? _driverRefreshTimer;
  static bool _driverRefreshInFlight = false;
  static String? _seasonOverride;
  static const String _favoriteDriverWidgetIdsKey =
      'favorite_driver_widget_ids';
  static const String _favoriteTeamWidgetIdsKey = 'favorite_team_widget_ids';
  static const String widgetsLastUpdatedKey = 'widgets_last_updated_ms';
  static const String _favoriteDriverDefaultKey = 'favorite_driver_default';
  static const String _favoriteTeamDefaultKey = 'favorite_team_default';
  static const String _driverWidgetTransparentKey = 'driver_widget_transparent';
  static const String _teamWidgetTransparentKey = 'team_widget_transparent';
  static const String _raceWeekendWidgetTransparentKey =
      'race_weekend_widget_transparent';
  static const String _favoriteDriverDefaultTransparentKey =
      '${_favoriteDriverDefaultKey}_transparent';
  static const String _favoriteTeamDefaultTransparentKey =
      '${_favoriteTeamDefaultKey}_transparent';

  static Future<void> ensureHomeWidgetSetup({bool strict = false}) async {
    try {
      final configured = await HomeWidget.setAppGroupId(iOSAppGroupId);
      if (strict && configured != true) {
        throw StateError('home_widget app group setup returned $configured');
      }
    } catch (_) {
      // App group setup is required for iOS widgets but should not block app startup.
      if (strict) rethrow;
    }
  }

  static void startDriverStandingsAutoRefresh({
    Duration interval = defaultRefreshInterval,
  }) {
    _driverRefreshTimer?.cancel();
    _driverRefreshTimer = Timer.periodic(interval, (_) {
      refreshDriverStandings();
    });
    refreshDriverStandings();
  }

  static void stopDriverStandingsAutoRefresh() {
    _driverRefreshTimer?.cancel();
    _driverRefreshTimer = null;
  }

  /// Refreshes every widget dataset and reports each fetch, persistence, and
  /// native reload phase independently.
  ///
  /// Unlike the foreground auto-refresh helpers, this method never hides a
  /// required failure. Background workers must check [WidgetRefreshResult.succeeded]
  /// before recording a healthy run.
  static Future<WidgetRefreshResult> refreshAllWidgets({
    ApiService? apiService,
  }) async {
    final api = apiService ?? ApiService();
    final season = _seasonOverride ?? DateTime.now().year.toString();
    final steps = <WidgetRefreshStepResult>[];

    Future<T?> fetch<T>(
      String dataset,
      Future<T> Function() operation, {
      bool required = true,
    }) async {
      try {
        final value = await operation();
        steps.add(
          WidgetRefreshStepResult(
            dataset: dataset,
            phase: WidgetRefreshPhase.fetch,
            succeeded: true,
            required: required,
          ),
        );
        return value;
      } catch (error, stackTrace) {
        steps.add(
          WidgetRefreshStepResult(
            dataset: dataset,
            phase: WidgetRefreshPhase.fetch,
            succeeded: false,
            required: required,
            error: error,
            stackTrace: stackTrace,
          ),
        );
        _logWidgetError('refreshAllWidgets.$dataset.fetch', error, stackTrace);
        return null;
      }
    }

    Future<bool> runPhase(
      String dataset,
      WidgetRefreshPhase phase,
      Future<void> Function() operation,
    ) async {
      try {
        await operation();
        steps.add(
          WidgetRefreshStepResult(
            dataset: dataset,
            phase: phase,
            succeeded: true,
          ),
        );
        return true;
      } catch (error, stackTrace) {
        steps.add(
          WidgetRefreshStepResult(
            dataset: dataset,
            phase: phase,
            succeeded: false,
            error: error,
            stackTrace: stackTrace,
          ),
        );
        _logWidgetError(
          'refreshAllWidgets.$dataset.${phase.name}',
          error,
          stackTrace,
        );
        return false;
      }
    }

    void recordSkipped(String dataset, WidgetRefreshPhase phase, String cause) {
      steps.add(
        WidgetRefreshStepResult(
          dataset: dataset,
          phase: phase,
          succeeded: false,
          error: StateError(cause),
        ),
      );
    }

    Future<void> persistAndReload(
      String dataset,
      Future<void> Function() persist,
      Future<void> Function() reload,
    ) async {
      final persisted = await runPhase(
        dataset,
        WidgetRefreshPhase.persist,
        persist,
      );
      if (persisted) {
        await runPhase(dataset, WidgetRefreshPhase.reload, reload);
      } else {
        recordSkipped(
          dataset,
          WidgetRefreshPhase.reload,
          'Reload skipped because persistence failed',
        );
      }
    }

    var driverStandings = await fetch<List<DriverStanding>>(
      'driverStandings',
      () => api.getDriverStandings(season: season),
    );
    var constructorStandings = await fetch<List<ConstructorStanding>>(
      'teamStandings',
      () => api.getConstructorStandings(season: season),
    );
    final races = await fetch<List<Race>>(
      'raceSchedule',
      () => api.getRaceSchedule(season: season),
    );
    final nextRace = await fetch<Race?>(
      'nextRace',
      () => api.getNextRace(season: season),
      required: false,
    );

    // Off-season: the new season has a calendar but no standings yet, so
    // show last season's final standings instead of empty widgets.
    String? standingsSeason;
    final year = int.tryParse(season);
    if (year != null &&
        driverStandings != null &&
        constructorStandings != null &&
        driverStandings.isEmpty &&
        constructorStandings.isEmpty) {
      try {
        final previous = '${year - 1}';
        final previousDrivers = await api.getDriverStandings(season: previous);
        final previousTeams = await api.getConstructorStandings(
          season: previous,
        );
        if (previousDrivers.isNotEmpty || previousTeams.isNotEmpty) {
          driverStandings = previousDrivers;
          constructorStandings = previousTeams;
          standingsSeason = previous;
        }
      } catch (_) {
        // Best effort: empty current-season widgets are still correct.
      }
    }
    // Promoted to non-null locals so the closures below see stable values.
    final drivers = driverStandings;
    final teams = constructorStandings;

    if (drivers != null) {
      await persistAndReload(
        'driverStandings',
        () => updateDriverStandings(
          drivers,
          season: season,
          standingsSeason: standingsSeason,
          reload: false,
        ),
        _refreshDriverWidget,
      );
      await persistAndReload(
        'favoriteDrivers',
        () => updateFavoriteDrivers(
          drivers,
          season: season,
          standingsSeason: standingsSeason,
          reload: false,
        ),
        _refreshFavoriteDriverWidget,
      );
    } else {
      for (final dataset in ['driverStandings', 'favoriteDrivers']) {
        recordSkipped(
          dataset,
          WidgetRefreshPhase.persist,
          'Persistence skipped because driver standings fetch failed',
        );
        recordSkipped(
          dataset,
          WidgetRefreshPhase.reload,
          'Reload skipped because driver standings fetch failed',
        );
      }
    }

    if (teams != null) {
      await persistAndReload(
        'teamStandings',
        () => updateTeamStandings(
          teams,
          season: season,
          standingsSeason: standingsSeason,
          reload: false,
        ),
        _refreshTeamWidget,
      );
      if (drivers != null) {
        await persistAndReload(
          'favoriteTeams',
          () => updateFavoriteTeams(
            teams,
            season: season,
            standingsSeason: standingsSeason,
            drivers: drivers,
            reload: false,
          ),
          _refreshFavoriteTeamWidget,
        );
      } else {
        recordSkipped(
          'favoriteTeams',
          WidgetRefreshPhase.persist,
          'Persistence skipped because driver standings fetch failed',
        );
        recordSkipped(
          'favoriteTeams',
          WidgetRefreshPhase.reload,
          'Reload skipped because driver standings fetch failed',
        );
      }
    } else {
      for (final dataset in ['teamStandings', 'favoriteTeams']) {
        recordSkipped(
          dataset,
          WidgetRefreshPhase.persist,
          'Persistence skipped because team standings fetch failed',
        );
        recordSkipped(
          dataset,
          WidgetRefreshPhase.reload,
          'Reload skipped because team standings fetch failed',
        );
      }
    }

    if (races != null) {
      await persistAndReload(
        'raceWeekend',
        () => updateRaceWeekend(
          races,
          nextRace: nextRace,
          season: season,
          reload: false,
        ),
        _refreshRaceWeekendWidget,
      );
    } else {
      for (final dataset in ['raceWeekend']) {
        recordSkipped(
          dataset,
          WidgetRefreshPhase.persist,
          'Persistence skipped because race schedule fetch failed',
        );
        recordSkipped(
          dataset,
          WidgetRefreshPhase.reload,
          'Reload skipped because race schedule fetch failed',
        );
      }
    }

    return WidgetRefreshResult(List.unmodifiable(steps));
  }

  static Future<void> refreshDriverStandings() async {
    if (_driverRefreshInFlight) {
      return;
    }
    _driverRefreshInFlight = true;
    try {
      final season = _seasonOverride ?? DateTime.now().year.toString();
      final api = ApiService();
      try {
        final standings = await api.getStandingsOrPreviousSeason(
          season: season,
        );
        final standingsSeason = standings.isPreviousSeason
            ? standings.season
            : null;
        final drivers = standings.drivers.data;
        final teams = standings.constructors.data;
        await updateDriverStandings(
          drivers,
          season: season,
          standingsSeason: standingsSeason,
        );
        await updateFavoriteDrivers(
          drivers,
          season: season,
          standingsSeason: standingsSeason,
        );
        await updateTeamStandings(
          teams,
          season: season,
          standingsSeason: standingsSeason,
        );
        await updateFavoriteTeams(
          teams,
          season: season,
          standingsSeason: standingsSeason,
          drivers: drivers,
        );
      } catch (error, stackTrace) {
        // Intentional: a standings failure must not block the race weekend
        // widget below. Log so a blank widget can be traced to its endpoint.
        _logWidgetError('refreshDriverStandings.standings', error, stackTrace);
      }
      try {
        final races = await api.getRaceSchedule(season: season);
        await updateRaceWeekend(races, season: season);
      } catch (error, stackTrace) {
        _logWidgetError(
          'refreshDriverStandings.scheduleWidgets',
          error,
          stackTrace,
        );
      }
    } catch (error, stackTrace) {
      // Intentional: keep periodic background runs alive. Inner catches
      // already isolated per-widget failures; this catches anything outside
      // those (e.g. the season lookup itself).
      _logWidgetError('refreshDriverStandings', error, stackTrace);
    } finally {
      _driverRefreshInFlight = false;
    }
  }

  static void _logWidgetError(
    String context,
    Object error,
    StackTrace stackTrace,
  ) {
    if (kDebugMode) {
      debugPrint('WidgetUpdateService [$context] failed: $error');
      debugPrint('$stackTrace');
    }
    unawaited(
      CrashReporting.captureException(
        error,
        stackTrace: stackTrace,
        hint: 'widget_update_service.$context',
        tags: {'context': context},
      ),
    );
  }

  static Future<void> updateDriverStandings(
    List<DriverStanding> standings, {
    String? season,
    String? standingsSeason,
    bool reload = true,
  }) async {
    final seasonLabel =
        season ?? _seasonOverride ?? DateTime.now().year.toString();
    _seasonOverride = seasonLabel;
    // Off-season: standings come from last season, the calendar does not.
    final displaySeason = standingsSeason ?? seasonLabel;
    final top = standings.take(3).toList();
    await _saveDps('driver_widget_title', 'Driver Standings');
    await _saveDps(
      'driver_widget_subtitle',
      standings.isEmpty
          ? 'Standings coming soon'
          : displaySeason != seasonLabel
          ? '$displaySeason final standings'
          : 'Top 3 drivers',
    );
    await _saveDps('driver_widget_season', displaySeason);
    await _saveDps('driver_1', _formatDriver(top, 0));
    await _saveDps('driver_2', _formatDriver(top, 1));
    await _saveDps('driver_3', _formatDriver(top, 2));

    // Store separate fields for podium layout.
    for (int i = 0; i < 3; i++) {
      final idx = i + 1;
      if (i < top.length) {
        await _saveDps(
          'driver_${idx}_last_name',
          top[i].familyName.toUpperCase(),
        );
        await _saveDps('driver_${idx}_first_name', top[i].givenName);
        await _saveDps('driver_${idx}_pts', top[i].points);
        await _saveDps('driver_${idx}_code', _shortDriverCode(top[i]));
        await _saveDps('driver_${idx}_id', top[i].driverId);
      } else {
        await _saveDps('driver_${idx}_last_name', 'TBD');
        await _saveDps('driver_${idx}_first_name', '');
        await _saveDps('driver_${idx}_pts', '0');
        await _saveDps('driver_${idx}_code', '---');
        await _saveDps('driver_${idx}_id', '');
      }
    }

    // Download headshot images for top 3 drivers.
    for (int i = 0; i < top.length && i < 3; i++) {
      await _saveDriverImage(
        'driver_${i + 1}_image',
        permanentNumber: top[i].permanentNumber,
        code: top[i].code,
      );
    }

    if (reload) {
      await _refreshDriverWidget();
    }
  }

  static Future<void> updateTeamStandings(
    List<ConstructorStanding> standings, {
    String? season,
    String? standingsSeason,
    bool reload = true,
  }) async {
    final seasonLabel =
        season ?? _seasonOverride ?? DateTime.now().year.toString();
    _seasonOverride = seasonLabel;
    // Off-season: standings come from last season, the calendar does not.
    final displaySeason = standingsSeason ?? seasonLabel;
    final top = standings.take(3).toList();
    await _saveDps('team_widget_title', 'Team Standings');
    await _saveDps(
      'team_widget_subtitle',
      standings.isEmpty
          ? 'Standings coming soon'
          : displaySeason != seasonLabel
          ? '$displaySeason final standings'
          : 'Top 3 teams',
    );
    await _saveDps('team_widget_season', displaySeason);
    await _saveDps('team_1', _formatTeam(top, 0));
    await _saveDps('team_2', _formatTeam(top, 1));
    await _saveDps('team_3', _formatTeam(top, 2));

    // Store separate fields for podium layout + team logos.
    for (int i = 0; i < 3; i++) {
      final idx = i + 1;
      if (i < top.length) {
        await _saveDps('team_${idx}_name', top[i].teamName);
        await _saveDps('team_${idx}_pts', top[i].points);
        await _saveTeamLogo('team_${idx}_logo', top[i].teamName);
        await _saveDps('team_${idx}_id', top[i].constructorId);
      } else {
        await _saveDps('team_${idx}_name', 'TBD');
        await _saveDps('team_${idx}_pts', '0');
        await _saveDps('team_${idx}_id', '');
      }
    }

    if (reload) {
      await _refreshTeamWidget();
    }
  }

  /// Combined Race Weekend widget — shows race info + all sessions + countdown.
  static Future<void> updateRaceWeekend(
    List<Race> races, {
    Race? nextRace,
    String? season,
    bool reload = true,
  }) async {
    final seasonLabel =
        season ?? _seasonOverride ?? DateTime.now().year.toString();
    _seasonOverride = seasonLabel;
    await _saveDps('race_weekend_widget_title', 'Race Weekend');
    await _saveDps('race_weekend_widget_season', seasonLabel);

    final now = DateTime.now();
    final target = _selectRaceWeekendTarget(
      races,
      preferred: nextRace,
      now: now,
    );

    if (target == null) {
      await _saveDps('race_weekend_widget_name', 'No upcoming race');
      await _saveDps('race_weekend_widget_location', 'Season complete');
      await _saveDps('race_weekend_widget_countdown', 'Awaiting next calendar');
      await _saveDps('race_weekend_widget_next_session_name', '');
      await _saveDps('race_weekend_widget_target_ms', '');
      await _saveDps('race_weekend_widget_round', '');
      for (int i = 1; i <= 7; i++) {
        await _saveDps('race_weekend_widget_session_$i', '');
        await _saveDps('race_weekend_widget_session_${i}_name', '');
        await _saveDps('race_weekend_widget_session_${i}_ms', '');
      }
      await _saveDps('race_weekend_widget_next_index', '-1');
    } else {
      await _saveDps(
        'race_weekend_widget_name',
        target.raceName.isEmpty ? 'Race weekend' : target.raceName,
      );
      await _saveDps(
        'race_weekend_widget_location',
        target.location.isEmpty
            ? (target.circuitName.isEmpty ? 'Location TBA' : target.circuitName)
            : target.location,
      );
      await _saveDps('race_weekend_widget_round', 'R${target.round}');
      await _saveTrackImage('race_weekend_widget_track', target.circuitId);

      // Build session lines for this race in chronological order (the model
      // lists qualifying before the sprint sessions on sprint weekends).
      final allSessions = sortSessionsChronologically(target.sessions);
      int nextIndex = -1;

      for (int i = 0; i < 7; i++) {
        if (i < allSessions.length) {
          final session = allSessions[i];
          final label = _formatSessionLine(
            _UpcomingSession(race: target, session: session),
          );
          await _saveDps('race_weekend_widget_session_${i + 1}', label ?? '');
          // Raw name + start timestamp let the native widget derive
          // done / live / next state and format times locally.
          await _saveDps(
            'race_weekend_widget_session_${i + 1}_name',
            session.name,
          );
          await _saveDps(
            'race_weekend_widget_session_${i + 1}_ms',
            session.startDateTime?.toUtc().millisecondsSinceEpoch.toString() ??
                '',
          );

          // Track the first upcoming session.
          if (nextIndex == -1) {
            final start = session.startDateTime;
            if (start != null && start.isAfter(now)) {
              nextIndex = i;
            }
          }
        } else {
          await _saveDps('race_weekend_widget_session_${i + 1}', '');
          await _saveDps('race_weekend_widget_session_${i + 1}_name', '');
          await _saveDps('race_weekend_widget_session_${i + 1}_ms', '');
        }
      }

      await _saveDps('race_weekend_widget_next_index', nextIndex.toString());

      // Persist target timestamp + label so the native widget can recompute
      // the countdown locally on every onUpdate. The formatted string is
      // still saved as a fallback if the timestamp can't be parsed.
      DateTime? countdownTarget;
      String countdownLabel;
      if (nextIndex >= 0 && nextIndex < allSessions.length) {
        final nextSession = allSessions[nextIndex];
        countdownTarget = nextSession.startDateTime;
        await _saveDps(
          'race_weekend_widget_next_session_name',
          nextSession.name,
        );
        final countdownText = _formatCountdownLabel(countdownTarget);
        countdownLabel = '${nextSession.name} • $countdownText';
      } else {
        countdownTarget = target.startDateTime;
        await _saveDps('race_weekend_widget_next_session_name', '');
        countdownLabel = _formatCountdownLabel(countdownTarget);
      }
      await _saveDps('race_weekend_widget_countdown', countdownLabel);
      await _saveDps(
        'race_weekend_widget_target_ms',
        countdownTarget?.toUtc().millisecondsSinceEpoch.toString() ?? '',
      );
    }

    if (reload) {
      await _refreshRaceWeekendWidget();
    }
  }

  /// Returns [sessions] ordered by start time. Sessions without a parseable
  /// start keep their relative order and sort after timed ones.
  static List<RaceSession> sortSessionsChronologically(
    List<RaceSession> sessions,
  ) {
    final indexed = sessions.asMap().entries.toList();
    indexed.sort((a, b) {
      final aStart = a.value.startDateTime;
      final bStart = b.value.startDateTime;
      if (aStart == null && bStart == null) return a.key.compareTo(b.key);
      if (aStart == null) return 1;
      if (bStart == null) return -1;
      final cmp = aStart.compareTo(bStart);
      return cmp != 0 ? cmp : a.key.compareTo(b.key);
    });
    return [for (final entry in indexed) entry.value];
  }

  static Future<void> updateFavoriteDrivers(
    List<DriverStanding> standings, {
    String? season,
    String? standingsSeason,
    bool reload = true,
  }) async {
    final seasonLabel =
        season ?? _seasonOverride ?? DateTime.now().year.toString();
    _seasonOverride = seasonLabel;
    // Off-season: standings come from last season, the calendar does not.
    final displaySeason = standingsSeason ?? seasonLabel;
    final widgetIds = await _getWidgetIds(_favoriteDriverWidgetIdsKey);
    for (final widgetId in widgetIds) {
      final driverId = await _getDps(_favoriteDriverKey(widgetId, 'driverId'));
      final driver = standings.firstWhere(
        (item) => item.driverId == driverId,
        orElse: () => DriverStanding(
          position: '-',
          points: '0',
          wins: '0',
          givenName: 'Tap to',
          familyName: 'configure',
          teamName: '',
          driverId: '',
          constructorId: '',
          code: null,
          permanentNumber: null,
        ),
      );
      await _saveDps(_favoriteDriverKey(widgetId, 'name'), _driverName(driver));
      await _saveDps(_favoriteDriverKey(widgetId, 'team'), driver.teamName);
      await _saveDps(_favoriteDriverKey(widgetId, 'position'), driver.position);
      await _saveDps(
        _favoriteDriverKey(widgetId, 'points'),
        '${driver.points} pts',
      );
      await _saveDps(_favoriteDriverKey(widgetId, 'season'), displaySeason);
      await _saveFavoriteDriverDetails(
        _favoriteDriverKey(widgetId, ''),
        driver,
      );
      await _saveDriverImage(
        _favoriteDriverKey(widgetId, 'image'),
        permanentNumber: driver.permanentNumber,
        code: driver.code,
      );
    }

    final defaultDriverId = await _getDps(
      '${_favoriteDriverDefaultKey}_driverId',
    );
    if (defaultDriverId != null && defaultDriverId.isNotEmpty) {
      final defaultDriver = standings
          .where((driver) => driver.driverId == defaultDriverId)
          .firstOrNull;
      if (defaultDriver != null) {
        await setFavoriteDriverDefault(
          driver: defaultDriver,
          season: displaySeason,
          reload: false,
        );
      }
    }

    if (reload) {
      await _refreshFavoriteDriverWidget();
    }
  }

  static Future<void> updateFavoriteTeams(
    List<ConstructorStanding> standings, {
    String? season,
    String? standingsSeason,
    List<DriverStanding>? drivers,
    bool reload = true,
  }) async {
    final seasonLabel =
        season ?? _seasonOverride ?? DateTime.now().year.toString();
    _seasonOverride = seasonLabel;
    // Off-season: standings come from last season, the calendar does not.
    final displaySeason = standingsSeason ?? seasonLabel;
    final widgetIds = await _getWidgetIds(_favoriteTeamWidgetIdsKey);
    final currentDrivers =
        drivers ?? await ApiService().getDriverStandings(season: displaySeason);
    for (final widgetId in widgetIds) {
      final constructorId = await _getDps(
        _favoriteTeamKey(widgetId, 'constructorId'),
      );
      final team = standings.firstWhere(
        (item) => item.constructorId == constructorId,
        orElse: () => ConstructorStanding(
          position: '-',
          points: '0',
          wins: '0',
          teamName: 'Tap to configure',
          constructorId: '',
        ),
      );
      final teamDrivers = currentDrivers
          .where((driver) => driver.constructorId == team.constructorId)
          .take(2)
          .toList();
      await _saveDps(_favoriteTeamKey(widgetId, 'name'), team.teamName);
      await _saveDps(_favoriteTeamKey(widgetId, 'position'), team.position);
      await _saveDps(
        _favoriteTeamKey(widgetId, 'points'),
        '${team.points} pts',
      );
      await _saveDps(
        _favoriteTeamKey(widgetId, 'driver1'),
        _formatDriverLine(teamDrivers, 0),
      );
      await _saveDps(
        _favoriteTeamKey(widgetId, 'driver2'),
        _formatDriverLine(teamDrivers, 1),
      );
      await _saveDps(_favoriteTeamKey(widgetId, 'season'), displaySeason);
      await _saveTeamDetails(
        _favoriteTeamKey(widgetId, ''),
        team.teamName,
        teamDrivers,
      );
      await _saveCarImage(
        _favoriteTeamKey(widgetId, 'car_image'),
        team.constructorId,
      );
    }

    final defaultConstructorId = await _getDps(
      '${_favoriteTeamDefaultKey}_constructorId',
    );
    if (defaultConstructorId != null && defaultConstructorId.isNotEmpty) {
      final defaultTeam = standings
          .where((team) => team.constructorId == defaultConstructorId)
          .firstOrNull;
      if (defaultTeam != null) {
        await setFavoriteTeamDefault(
          team: defaultTeam,
          drivers: currentDrivers
              .where(
                (driver) => driver.constructorId == defaultTeam.constructorId,
              )
              .take(2)
              .toList(),
          season: displaySeason,
          reload: false,
        );
      }
    }

    if (reload) {
      await _refreshFavoriteTeamWidget();
    }
  }

  static Future<void> setFavoriteDriverDefault({
    required DriverStanding driver,
    required String season,
    bool reload = true,
  }) async {
    await _saveDps('${_favoriteDriverDefaultKey}_driverId', driver.driverId);
    await _saveDps('${_favoriteDriverDefaultKey}_name', _driverName(driver));
    await _saveDps('${_favoriteDriverDefaultKey}_team', driver.teamName);
    await _saveDps('${_favoriteDriverDefaultKey}_position', driver.position);
    await _saveDps(
      '${_favoriteDriverDefaultKey}_points',
      '${driver.points} pts',
    );
    await _saveDps('${_favoriteDriverDefaultKey}_season', season);
    await _saveFavoriteDriverDetails('${_favoriteDriverDefaultKey}_', driver);
    await _saveDriverImage(
      '${_favoriteDriverDefaultKey}_image',
      permanentNumber: driver.permanentNumber,
      code: driver.code,
    );
    if (reload) {
      await _refreshFavoriteDriverWidget();
    }
  }

  static Future<void> setFavoriteTeamDefault({
    required ConstructorStanding team,
    required List<DriverStanding> drivers,
    required String season,
    bool reload = true,
  }) async {
    await _saveDps(
      '${_favoriteTeamDefaultKey}_constructorId',
      team.constructorId,
    );
    await _saveDps('${_favoriteTeamDefaultKey}_name', team.teamName);
    await _saveDps('${_favoriteTeamDefaultKey}_position', team.position);
    await _saveDps('${_favoriteTeamDefaultKey}_points', '${team.points} pts');
    await _saveDps(
      '${_favoriteTeamDefaultKey}_driver1',
      _formatDriverLine(drivers, 0),
    );
    await _saveDps(
      '${_favoriteTeamDefaultKey}_driver2',
      _formatDriverLine(drivers, 1),
    );
    await _saveDps('${_favoriteTeamDefaultKey}_season', season);
    await _saveTeamDetails(
      '${_favoriteTeamDefaultKey}_',
      team.teamName,
      drivers,
    );
    await _saveCarImage(
      '${_favoriteTeamDefaultKey}_car_image',
      team.constructorId,
    );
    if (reload) {
      await _refreshFavoriteTeamWidget();
    }
  }

  static Future<void> setFavoriteDriverDefaultTransparent(bool value) async {
    await _saveDps(_favoriteDriverDefaultTransparentKey, value.toString());
    await _refreshFavoriteDriverWidget();
  }

  static Future<void> setFavoriteTeamDefaultTransparent(bool value) async {
    await _saveDps(_favoriteTeamDefaultTransparentKey, value.toString());
    await _refreshFavoriteTeamWidget();
  }

  static Future<void> configureFavoriteDriverWidget({
    required int widgetId,
    required DriverStanding driver,
    required String season,
  }) async {
    final widgetIds = await _getWidgetIds(_favoriteDriverWidgetIdsKey);
    widgetIds.add(widgetId);
    await _saveWidgetIds(_favoriteDriverWidgetIdsKey, widgetIds);
    await _saveDps(_favoriteDriverKey(widgetId, 'driverId'), driver.driverId);
    await _saveDps(_favoriteDriverKey(widgetId, 'name'), _driverName(driver));
    await _saveDps(_favoriteDriverKey(widgetId, 'team'), driver.teamName);
    await _saveDps(_favoriteDriverKey(widgetId, 'position'), driver.position);
    await _saveDps(
      _favoriteDriverKey(widgetId, 'points'),
      '${driver.points} pts',
    );
    await _saveDps(_favoriteDriverKey(widgetId, 'season'), season);
    await _saveFavoriteDriverDetails(_favoriteDriverKey(widgetId, ''), driver);
    await _saveDriverImage(
      _favoriteDriverKey(widgetId, 'image'),
      permanentNumber: driver.permanentNumber,
      code: driver.code,
    );
    await _refreshFavoriteDriverWidget();
  }

  static Future<void> configureFavoriteTeamWidget({
    required int widgetId,
    required ConstructorStanding team,
    required List<DriverStanding> drivers,
    required String season,
  }) async {
    final widgetIds = await _getWidgetIds(_favoriteTeamWidgetIdsKey);
    widgetIds.add(widgetId);
    await _saveWidgetIds(_favoriteTeamWidgetIdsKey, widgetIds);
    await _saveDps(
      _favoriteTeamKey(widgetId, 'constructorId'),
      team.constructorId,
    );
    await _saveDps(_favoriteTeamKey(widgetId, 'name'), team.teamName);
    await _saveDps(_favoriteTeamKey(widgetId, 'position'), team.position);
    await _saveDps(_favoriteTeamKey(widgetId, 'points'), '${team.points} pts');
    await _saveDps(
      _favoriteTeamKey(widgetId, 'driver1'),
      _formatDriverLine(drivers, 0),
    );
    await _saveDps(
      _favoriteTeamKey(widgetId, 'driver2'),
      _formatDriverLine(drivers, 1),
    );
    await _saveDps(_favoriteTeamKey(widgetId, 'season'), season);
    await _saveTeamDetails(
      _favoriteTeamKey(widgetId, ''),
      team.teamName,
      drivers,
    );
    await _saveCarImage(
      _favoriteTeamKey(widgetId, 'car_image'),
      team.constructorId,
    );
    await _refreshFavoriteTeamWidget();
  }

  static Future<void> setDriverWidgetTransparent(bool value) async {
    await _saveDps(_driverWidgetTransparentKey, value.toString());
    await _refreshDriverWidget();
  }

  static Future<void> setTeamWidgetTransparent(bool value) async {
    await _saveDps(_teamWidgetTransparentKey, value.toString());
    await _refreshTeamWidget();
  }

  static Future<void> setFavoriteDriverWidgetTransparent({
    required int widgetId,
    required bool value,
  }) async {
    await _saveDps(
      _favoriteDriverKey(widgetId, 'transparent'),
      value.toString(),
    );
    await _refreshFavoriteDriverWidget();
  }

  static Future<void> setFavoriteTeamWidgetTransparent({
    required int widgetId,
    required bool value,
  }) async {
    await _saveDps(_favoriteTeamKey(widgetId, 'transparent'), value.toString());
    await _refreshFavoriteTeamWidget();
  }

  static Future<bool> getDriverWidgetTransparent() async {
    return _getBool(_driverWidgetTransparentKey);
  }

  static Future<bool> getTeamWidgetTransparent() async {
    return _getBool(_teamWidgetTransparentKey);
  }

  static Future<bool> getFavoriteDriverWidgetTransparent(int widgetId) async {
    return _getBool(_favoriteDriverKey(widgetId, 'transparent'));
  }

  static Future<bool> getFavoriteTeamWidgetTransparent(int widgetId) async {
    return _getBool(_favoriteTeamKey(widgetId, 'transparent'));
  }

  static Future<bool> getFavoriteDriverDefaultTransparent() async {
    return _getBool(_favoriteDriverDefaultTransparentKey);
  }

  static Future<bool> getFavoriteTeamDefaultTransparent() async {
    return _getBool(_favoriteTeamDefaultTransparentKey);
  }

  /// Stamps when widget data was last persisted, shown natively as
  /// "Updated 2:41 PM".
  static Future<void> _markWidgetsUpdated() async {
    await _saveDps(
      widgetsLastUpdatedKey,
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  static Future<void> _refreshDriverWidget() async {
    await _markWidgetsUpdated();
    final updated = await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedDriverWidgetProvider,
      iOSName: iOSDriverWidgetKind,
    );
    _requirePluginSuccess('reload driver widget', updated);
  }

  static Future<void> _refreshTeamWidget() async {
    await _markWidgetsUpdated();
    final updated = await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedTeamWidgetProvider,
      iOSName: iOSTeamWidgetKind,
    );
    _requirePluginSuccess('reload team widget', updated);
  }

  static Future<void> _refreshFavoriteDriverWidget() async {
    await _markWidgetsUpdated();
    final updated = await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedFavoriteDriverWidgetProvider,
      iOSName: iOSFavoriteDriverWidgetKind,
    );
    _requirePluginSuccess('reload favorite driver widget', updated);
  }

  static Future<void> _refreshFavoriteTeamWidget() async {
    await _markWidgetsUpdated();
    final updated = await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedFavoriteTeamWidgetProvider,
      iOSName: iOSFavoriteTeamWidgetKind,
    );
    _requirePluginSuccess('reload favorite team widget', updated);
  }

  static Future<void> _refreshRaceWeekendWidget() async {
    await _markWidgetsUpdated();
    final updated = await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedRaceWeekendWidgetProvider,
      iOSName: iOSRaceWeekendWidgetKind,
    );
    _requirePluginSuccess('reload race weekend widget', updated);
  }

  static Future<void> setRaceWeekendWidgetTransparent(bool value) async {
    await _saveDps(_raceWeekendWidgetTransparentKey, value.toString());
    await _refreshRaceWeekendWidget();
  }

  /// Saves team color, driver number, and last name for the favorite driver widget.
  static Future<void> _saveFavoriteDriverDetails(
    String prefix,
    DriverStanding driver,
  ) async {
    final color = teamColor(driver.teamName);
    final hex = color
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase();
    await _saveDps('${prefix}team_color', '#$hex');
    await _saveDps('${prefix}last_name', driver.familyName.toUpperCase());
    await _saveDps('${prefix}number', driver.permanentNumber ?? '--');
    await _saveDps('${prefix}code', _shortDriverCode(driver));
  }

  /// Saves team color hex and individual driver details for the favorite team widget.
  static Future<void> _saveTeamDetails(
    String prefix,
    String teamName,
    List<DriverStanding> drivers,
  ) async {
    final color = teamColor(teamName);
    final hex = color
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase();
    await _saveDps('${prefix}team_color', '#$hex');
    for (int i = 0; i < 2; i++) {
      final idx = i + 1;
      if (i < drivers.length) {
        final d = drivers[i];
        await _saveDps('${prefix}d${idx}_name', d.familyName.toUpperCase());
        await _saveDps('${prefix}d${idx}_number', d.permanentNumber ?? '--');
        await _saveDps('${prefix}d${idx}_code', _shortDriverCode(d));
      } else {
        await _saveDps('${prefix}d${idx}_name', 'TBD');
        await _saveDps('${prefix}d${idx}_number', '--');
        await _saveDps('${prefix}d${idx}_code', '---');
      }
    }
  }

  /// Rasterizes a circuit SVG from Flutter assets to a PNG and saves it.
  static Future<void> _saveTrackImage(String imageKey, String circuitId) async {
    final assetPath = 'lib/assets/circuits/$circuitId.svg';
    try {
      final svgString = await rootBundle.loadString(assetPath);
      final pictureInfo = await vg.loadPicture(
        SvgStringLoader(svgString),
        null,
      );
      const targetWidth = 200.0;
      const targetHeight = 140.0;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Scale SVG to fit target size.
      final svgSize = pictureInfo.size;
      final scaleX = targetWidth / svgSize.width;
      final scaleY = targetHeight / svgSize.height;
      final scale = scaleX < scaleY ? scaleX : scaleY;
      final dx = (targetWidth - svgSize.width * scale) / 2;
      final dy = (targetHeight - svgSize.height * scale) / 2;
      canvas.translate(dx, dy);
      canvas.scale(scale);

      // Tint the track red.
      canvas.saveLayer(
        ui.Rect.fromLTWH(0, 0, svgSize.width, svgSize.height),
        ui.Paint()
          ..colorFilter = const ui.ColorFilter.mode(
            ui.Color(0xFFE10600),
            ui.BlendMode.srcIn,
          ),
      );
      canvas.drawPicture(pictureInfo.picture);
      canvas.restore();

      final picture = recorder.endRecording();
      final image = await picture.toImage(
        targetWidth.toInt(),
        targetHeight.toInt(),
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      pictureInfo.picture.dispose();
      image.dispose();
      if (byteData == null) return;

      await _saveWidgetImage(imageKey, byteData.buffer.asUint8List());
    } catch (_) {
      // SVG not found or render failure — widget shows without track image.
    }
  }

  /// Saves a team logo from Flutter assets to native widget storage.
  static Future<void> _saveTeamLogo(String imageKey, String teamName) async {
    final assetPath = _teamLogoAsset(teamName);
    if (assetPath == null) return;
    try {
      final data = await rootBundle.load(assetPath);
      await _saveWidgetImage(imageKey, data.buffer.asUint8List());
    } catch (_) {
      // Asset load failure is non-fatal.
    }
  }

  static String? _teamLogoAsset(String teamName) {
    final key = teamName.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    if (key.isEmpty) return null;
    const logos = {
      'redbull': 'lib/assets/images/red-bull.png',
      'redbullracing': 'lib/assets/images/red-bull.png',
      'rb': 'lib/assets/images/rb.png',
      'racingbulls': 'lib/assets/images/rb.png',
      'ferrari': 'lib/assets/images/ferrari.png',
      'scuderiaferrari': 'lib/assets/images/ferrari.png',
      'mercedes': 'lib/assets/images/mercedes.png',
      'mercedesamgpetronas': 'lib/assets/images/mercedes.png',
      'mclaren': 'lib/assets/images/mclaren.png',
      'astonmartin': 'lib/assets/images/aston.png',
      'alpine': 'lib/assets/images/alpine.png',
      'haas': 'lib/assets/images/haas.png',
      'williams': 'lib/assets/images/williams.png',
      'sauber': 'lib/assets/images/audi.png',
      'kicksauber': 'lib/assets/images/audi.png',
      'audi': 'lib/assets/images/audi.png',
      'cadillac': 'lib/assets/images/cadillac.png',
    };
    if (logos.containsKey(key)) return logos[key];
    for (final entry in logos.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Downloads a driver headshot and saves it to native widget storage.
  static Future<void> _saveDriverImage(
    String imageKey, {
    String? permanentNumber,
    String? code,
  }) async {
    final url = F1ImageService.instance.driverHeadshotUrl(
      permanentNumber: permanentNumber,
      code: code,
    );
    if (url == null) return;
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(_imageDownloadTimeout);
      if (response.statusCode == 200) {
        await _saveWidgetImage(
          imageKey,
          Uint8List.fromList(response.bodyBytes),
        );
      }
    } catch (_) {
      // Image download failure is non-fatal — widget falls back to placeholder.
    }
  }

  /// Downloads a team car image and saves it to native widget storage.
  static Future<void> _saveCarImage(
    String imageKey,
    String constructorId,
  ) async {
    final url = F1ImageService.instance.carImageUrl(constructorId);
    if (url == null) return;
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(_imageDownloadTimeout);
      if (response.statusCode == 200) {
        await _saveWidgetImage(
          imageKey,
          Uint8List.fromList(response.bodyBytes),
        );
      }
    } catch (_) {
      // Image download failure is non-fatal — widget falls back to placeholder.
    }
  }

  static Future<void> _saveDps(String id, String value) async {
    final saved = await HomeWidget.saveWidgetData<String>(id, value);
    _requirePluginSuccess('save widget data "$id"', saved);
  }

  static Future<String?> _getDps(String id, {String? defaultValue}) async {
    return HomeWidget.getWidgetData<String>(id, defaultValue: defaultValue);
  }

  static Future<void> _saveWidgetImage(String id, Uint8List bytes) async {
    final String? rootPath;
    if (Platform.isIOS) {
      rootPath = await PathProviderFoundation().getContainerPath(
        appGroupIdentifier: iOSAppGroupId,
      );
    } else {
      rootPath = (await getApplicationSupportDirectory()).path;
    }
    if (rootPath == null || rootPath.isEmpty) {
      throw StateError('Widget image storage is unavailable');
    }

    final file = File('$rootPath/home_widget/$id.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    final saved = await HomeWidget.saveWidgetData<String>(id, file.path);
    _requirePluginSuccess('save widget image "$id"', saved);
  }

  static void _requirePluginSuccess(String operation, bool? succeeded) {
    if (succeeded != true) {
      throw StateError('$operation returned $succeeded');
    }
  }

  static Future<bool> _getBool(String id) async {
    final value = await _getDps(id, defaultValue: 'false');
    return value == 'true';
  }

  static Future<Set<int>> _getWidgetIds(String key) async {
    final raw = await _getDps(key);
    if (raw == null || raw.isEmpty) {
      return <int>{};
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((id) => int.tryParse('$id') ?? 0)
          .where((id) => id > 0)
          .toSet();
    } catch (_) {
      return <int>{};
    }
  }

  static Future<void> _saveWidgetIds(String key, Set<int> ids) async {
    final payload = jsonEncode(ids.toList()..sort());
    await _saveDps(key, payload);
  }

  static String _favoriteDriverKey(int widgetId, String field) {
    return 'favorite_driver_widget_${widgetId}_$field';
  }

  static String _favoriteTeamKey(int widgetId, String field) {
    return 'favorite_team_widget_${widgetId}_$field';
  }

  static String _formatDriver(List<DriverStanding> top, int index) {
    if (index >= top.length) {
      return 'TBD';
    }
    final driver = top[index];
    return "${driver.givenName} ${driver.familyName} - ${driver.points} pts";
  }

  static String _formatTeam(List<ConstructorStanding> top, int index) {
    if (index >= top.length) {
      return 'TBD';
    }
    final team = top[index];
    return "${team.teamName} - ${team.points} pts";
  }

  static String _driverName(DriverStanding driver) {
    return "${driver.givenName} ${driver.familyName}".trim();
  }

  static String _shortDriverCode(DriverStanding driver) {
    final code = driver.code?.trim();
    if (code != null && code.isNotEmpty) {
      return code.toUpperCase();
    }
    final family = driver.familyName.trim();
    if (family.isEmpty) {
      return '---';
    }
    return family
        .substring(0, family.length >= 3 ? 3 : family.length)
        .toUpperCase();
  }

  static String _formatDriverLine(List<DriverStanding> drivers, int index) {
    if (index >= drivers.length) {
      return 'TBD';
    }
    final driver = drivers[index];
    final number = driver.permanentNumber ?? '--';
    final code = _shortDriverCode(driver);
    return "$number $code";
  }

  static String _formatDateTimeLabel(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Time TBA';
    }
    final local = dateTime.toLocal();
    final month = _monthLabel(local.month);
    final minute = local.minute.toString().padLeft(2, '0');
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final meridiem = local.hour >= 12 ? 'PM' : 'AM';
    return '$month ${local.day} • $hour:$minute $meridiem';
  }

  static String _formatCountdownLabel(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Time TBA';
    }
    final remaining = dateTime.difference(DateTime.now());
    if (remaining.isNegative) {
      return 'Weekend in progress';
    }
    if (remaining.inMinutes <= 0) {
      return 'Starting now';
    }
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;
    if (days > 0) {
      return 'Starts in ${days}d ${hours}h ${minutes}m';
    }
    if (remaining.inHours > 0) {
      return 'Starts in ${remaining.inHours}h ${minutes}m';
    }
    return 'Starts in ${minutes}m';
  }

  static Race? _selectRaceWeekendTarget(
    List<Race> races, {
    Race? preferred,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final candidates = races
        .where((race) => !_hasRaceWeekendEnded(race, currentTime))
        .toList();
    candidates.sort((a, b) {
      final aStart = _raceWeekendStart(a);
      final bStart = _raceWeekendStart(b);
      if (aStart == null && bStart == null) {
        return 0;
      }
      if (aStart == null) {
        return 1;
      }
      if (bStart == null) {
        return -1;
      }
      return aStart.compareTo(bStart);
    });
    if (candidates.isNotEmpty) {
      return candidates.first;
    }
    if (preferred != null && !_hasRaceWeekendEnded(preferred, currentTime)) {
      return preferred;
    }
    return null;
  }

  static bool _hasRaceWeekendEnded(Race race, DateTime now) {
    final end = _raceWeekendEnd(race);
    if (end == null) {
      return false;
    }
    return !end.add(_raceWeekendCompletionGrace).isAfter(now);
  }

  static DateTime? _raceWeekendStart(Race race) {
    DateTime? earliest;
    for (final session in race.sessions) {
      final start = session.startDateTime;
      if (start == null) {
        continue;
      }
      if (earliest == null || start.isBefore(earliest)) {
        earliest = start;
      }
    }
    return earliest;
  }

  static DateTime? _raceWeekendEnd(Race race) {
    DateTime? latest;
    for (final session in race.sessions) {
      final start = session.startDateTime;
      if (start == null) {
        continue;
      }
      if (latest == null || start.isAfter(latest)) {
        latest = start;
      }
    }
    return latest;
  }

  static String? _formatSessionLine(_UpcomingSession? item) {
    if (item == null) {
      return null;
    }
    final dateLabel = _formatDateTimeLabel(item.session.startDateTime);
    return '${item.session.name} • $dateLabel';
  }

  static String _monthLabel(int month) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > 12) {
      return '---';
    }
    return months[month - 1];
  }
}

class _UpcomingSession {
  final Race race;
  final RaceSession session;

  const _UpcomingSession({required this.race, required this.session});
}
