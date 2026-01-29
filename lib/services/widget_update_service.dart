import 'dart:async';
import 'dart:convert';

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
  static const String androidFavoriteDriverWidgetProvider =
      'FavoriteDriverWidgetProvider';
  static const String androidQualifiedFavoriteDriverWidgetProvider =
      'com.example.gridglance.FavoriteDriverWidgetProvider';
  static const String androidFavoriteTeamWidgetProvider =
      'FavoriteTeamWidgetProvider';
  static const String androidQualifiedFavoriteTeamWidgetProvider =
      'com.example.gridglance.FavoriteTeamWidgetProvider';
  static const MethodChannel _dpsChannel = MethodChannel('gridglance/dps');
  static const Duration defaultRefreshInterval = Duration(minutes: 30);
  static Timer? _driverRefreshTimer;
  static bool _driverRefreshInFlight = false;
  static String? _seasonOverride;
  static const String _favoriteDriverWidgetIdsKey = 'favorite_driver_widget_ids';
  static const String _favoriteTeamWidgetIdsKey = 'favorite_team_widget_ids';
  static const String _favoriteDriverDefaultKey = 'favorite_driver_default';
  static const String _favoriteTeamDefaultKey = 'favorite_team_default';
  static const String _driverWidgetTransparentKey = 'driver_widget_transparent';
  static const String _teamWidgetTransparentKey = 'team_widget_transparent';
  static const String _favoriteDriverDefaultTransparentKey =
      '${_favoriteDriverDefaultKey}_transparent';
  static const String _favoriteTeamDefaultTransparentKey =
      '${_favoriteTeamDefaultKey}_transparent';

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
        await updateFavoriteDrivers(standings, season: season);
      } catch (_) {
        // Ignore driver update errors.
      }
      try {
        final standings = await api.getConstructorStandings(season: season);
        await updateTeamStandings(standings, season: season);
        await updateFavoriteTeams(standings, season: season);
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
    final seasonLabel =
        season ?? _seasonOverride ?? DateTime.now().year.toString();
    _seasonOverride = seasonLabel;
    final top = standings.take(3).toList();
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
    final seasonLabel =
        season ?? _seasonOverride ?? DateTime.now().year.toString();
    _seasonOverride = seasonLabel;
    final top = standings.take(3).toList();
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

  static Future<void> updateFavoriteDrivers(
    List<DriverStanding> standings,
    {String? season}
  ) async {
    final seasonLabel =
        season ?? _seasonOverride ?? DateTime.now().year.toString();
    _seasonOverride = seasonLabel;
    final widgetIds = await _getWidgetIds(_favoriteDriverWidgetIdsKey);
    for (final widgetId in widgetIds) {
      final driverId = await _getDps(
        _favoriteDriverKey(widgetId, 'driverId'),
      );
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
      await _saveDps(
        _favoriteDriverKey(widgetId, 'name'),
        _driverName(driver),
      );
      await _saveDps(
        _favoriteDriverKey(widgetId, 'team'),
        driver.teamName,
      );
      await _saveDps(
        _favoriteDriverKey(widgetId, 'position'),
        driver.position,
      );
      await _saveDps(
        _favoriteDriverKey(widgetId, 'points'),
        '${driver.points} pts',
      );
      await _saveDps(_favoriteDriverKey(widgetId, 'season'), seasonLabel);
    }

    await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedFavoriteDriverWidgetProvider,
    );
  }

  static Future<void> updateFavoriteTeams(
    List<ConstructorStanding> standings,
    {String? season}
  ) async {
    final seasonLabel =
        season ?? _seasonOverride ?? DateTime.now().year.toString();
    _seasonOverride = seasonLabel;
    final widgetIds = await _getWidgetIds(_favoriteTeamWidgetIdsKey);
    final drivers = await ApiService().getDriverStandings(season: seasonLabel);
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
      final teamDrivers = drivers
          .where((driver) => driver.constructorId == team.constructorId)
          .take(2)
          .toList();
      await _saveDps(
        _favoriteTeamKey(widgetId, 'name'),
        team.teamName,
      );
      await _saveDps(
        _favoriteTeamKey(widgetId, 'position'),
        team.position,
      );
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
      await _saveDps(_favoriteTeamKey(widgetId, 'season'), seasonLabel);
    }

    await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedFavoriteTeamWidgetProvider,
    );
  }

  static Future<void> setFavoriteDriverDefault({
    required DriverStanding driver,
    required String season,
  }) async {
    await _saveDps('${_favoriteDriverDefaultKey}_driverId', driver.driverId);
    await _saveDps('${_favoriteDriverDefaultKey}_name', _driverName(driver));
    await _saveDps('${_favoriteDriverDefaultKey}_team', driver.teamName);
    await _saveDps('${_favoriteDriverDefaultKey}_position', driver.position);
    await _saveDps('${_favoriteDriverDefaultKey}_points', '${driver.points} pts');
    await _saveDps('${_favoriteDriverDefaultKey}_season', season);
    await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedFavoriteDriverWidgetProvider,
    );
  }

  static Future<void> setFavoriteTeamDefault({
    required ConstructorStanding team,
    required List<DriverStanding> drivers,
    required String season,
  }) async {
    await _saveDps('${_favoriteTeamDefaultKey}_constructorId', team.constructorId);
    await _saveDps('${_favoriteTeamDefaultKey}_name', team.teamName);
    await _saveDps('${_favoriteTeamDefaultKey}_position', team.position);
    await _saveDps('${_favoriteTeamDefaultKey}_points', '${team.points} pts');
    await _saveDps('${_favoriteTeamDefaultKey}_driver1', _formatDriverLine(drivers, 0));
    await _saveDps('${_favoriteTeamDefaultKey}_driver2', _formatDriverLine(drivers, 1));
    await _saveDps('${_favoriteTeamDefaultKey}_season', season);
    await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedFavoriteTeamWidgetProvider,
    );
  }

  static Future<void> setFavoriteDriverDefaultTransparent(bool value) async {
    await _saveDps(_favoriteDriverDefaultTransparentKey, value.toString());
    await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedFavoriteDriverWidgetProvider,
    );
  }

  static Future<void> setFavoriteTeamDefaultTransparent(bool value) async {
    await _saveDps(_favoriteTeamDefaultTransparentKey, value.toString());
    await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedFavoriteTeamWidgetProvider,
    );
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
    await _saveDps(_favoriteDriverKey(widgetId, 'points'), '${driver.points} pts');
    await _saveDps(_favoriteDriverKey(widgetId, 'season'), season);
    await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedFavoriteDriverWidgetProvider,
    );
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
    await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedFavoriteTeamWidgetProvider,
    );
  }

  static Future<void> setDriverWidgetTransparent(bool value) async {
    await _saveDps(_driverWidgetTransparentKey, value.toString());
    await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedDriverWidgetProvider,
    );
  }

  static Future<void> setTeamWidgetTransparent(bool value) async {
    await _saveDps(_teamWidgetTransparentKey, value.toString());
    await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedTeamWidgetProvider,
    );
  }

  static Future<void> setFavoriteDriverWidgetTransparent({
    required int widgetId,
    required bool value,
  }) async {
    await _saveDps(_favoriteDriverKey(widgetId, 'transparent'), value.toString());
    await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedFavoriteDriverWidgetProvider,
    );
  }

  static Future<void> setFavoriteTeamWidgetTransparent({
    required int widgetId,
    required bool value,
  }) async {
    await _saveDps(_favoriteTeamKey(widgetId, 'transparent'), value.toString());
    await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedFavoriteTeamWidgetProvider,
    );
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

  static Future<void> _saveDps(String id, String value) async {
    await _dpsChannel.invokeMethod<void>('saveWidgetData', {
      'id': id,
      'data': value,
    });
  }

  static Future<String?> _getDps(String id, {String? defaultValue}) async {
    return _dpsChannel.invokeMethod<String>('getWidgetData', {
      'id': id,
      'defaultValue': defaultValue,
    });
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
      return decoded.map((id) => int.tryParse('$id') ?? 0).where((id) => id > 0).toSet();
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
    return family.substring(0, family.length >= 3 ? 3 : family.length).toUpperCase();
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
}
