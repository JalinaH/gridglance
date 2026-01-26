import 'dart:async';

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../data/api_service.dart';
import '../models/constructor_standing.dart';
import '../models/driver_standing.dart';

class WidgetUpdateService {
  static const String androidDriverWidgetProvider =
      'DriverStandingsWidgetProvider';
  static const String androidQualifiedDriverWidgetProvider =
      'com.example.gridglance.DriverStandingsWidgetProvider';
  static const String androidTeamWidgetProvider =
      'TeamStandingsWidgetProvider';
  static const String androidQualifiedTeamWidgetProvider =
      'com.example.gridglance.TeamStandingsWidgetProvider';
  static const MethodChannel _dpsChannel = MethodChannel('gridglance/dps');
  static const Duration defaultRefreshInterval = Duration(minutes: 30);
  static Timer? _driverRefreshTimer;
  static bool _driverRefreshInFlight = false;
  static String? _seasonOverride;

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

  static Future<void> refreshDriverStandings() async {
    if (_driverRefreshInFlight) {
      return;
    }
    _driverRefreshInFlight = true;
    try {
      final season = _seasonOverride ?? DateTime.now().year.toString();
      final api = ApiService();
      try {
        final standings = await api.getDriverStandings(season: season);
        await updateDriverStandings(standings, season: season);
      } catch (_) {
        // Ignore driver update errors.
      }
      try {
        final standings = await api.getConstructorStandings(season: season);
        await updateTeamStandings(standings, season: season);
      } catch (_) {
        // Ignore team update errors.
      }
    } catch (_) {
      // Ignore refresh errors to keep periodic updates alive.
    } finally {
      _driverRefreshInFlight = false;
    }
  }

  static Future<void> updateDriverStandings(
    List<DriverStanding> standings,
    {String? season}
  ) async {
    final top = standings.take(3).toList();
    final seasonLabel =
        season ?? _seasonOverride ?? DateTime.now().year.toString();
    _seasonOverride = seasonLabel;
    await _saveDps('driver_widget_title', 'Driver Standings');
    await _saveDps(
      'driver_widget_subtitle',
      standings.isEmpty ? 'Standings coming soon' : 'Top 3 drivers',
    );
    await _saveDps('driver_widget_season', seasonLabel);
    await _saveDps('driver_1', _formatDriver(top, 0));
    await _saveDps('driver_2', _formatDriver(top, 1));
    await _saveDps('driver_3', _formatDriver(top, 2));

    await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedDriverWidgetProvider,
    );
  }

  static Future<void> updateTeamStandings(
    List<ConstructorStanding> standings,
    {String? season}
  ) async {
    final top = standings.take(3).toList();
    final seasonLabel =
        season ?? _seasonOverride ?? DateTime.now().year.toString();
    _seasonOverride = seasonLabel;
    await _saveDps('team_widget_title', 'Team Standings');
    await _saveDps(
      'team_widget_subtitle',
      standings.isEmpty ? 'Standings coming soon' : 'Top 3 teams',
    );
    await _saveDps('team_widget_season', seasonLabel);
    await _saveDps('team_1', _formatTeam(top, 0));
    await _saveDps('team_2', _formatTeam(top, 1));
    await _saveDps('team_3', _formatTeam(top, 2));

    await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedTeamWidgetProvider,
    );
  }

  static Future<void> _saveDps(String id, String value) async {
    await _dpsChannel.invokeMethod<void>('saveWidgetData', {
      'id': id,
      'data': value,
    });
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
}
