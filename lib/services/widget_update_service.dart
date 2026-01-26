import 'dart:async';

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../data/api_service.dart';
import '../models/driver_standing.dart';

class WidgetUpdateService {
  static const String androidDriverWidgetProvider =
      'DriverStandingsWidgetProvider';
  static const String androidQualifiedDriverWidgetProvider =
      'com.example.gridglance.DriverStandingsWidgetProvider';
  static const MethodChannel _dpsChannel = MethodChannel('gridglance/dps');
  static const Duration defaultRefreshInterval = Duration(minutes: 30);
  static Timer? _driverRefreshTimer;
  static bool _driverRefreshInFlight = false;

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
      final standings = await ApiService().getDriverStandings();
      await updateDriverStandings(standings);
    } catch (_) {
      // Ignore refresh errors to keep periodic updates alive.
    } finally {
      _driverRefreshInFlight = false;
    }
  }

  static Future<void> updateDriverStandings(
    List<DriverStanding> standings,
  ) async {
    if (standings.isEmpty) {
      return;
    }

    final top = standings.take(3).toList();
    await _saveDps('driver_widget_title', 'Driver Standings');
    await _saveDps('driver_widget_subtitle', 'Top 3 drivers');
    await _saveDps('driver_1', _formatDriver(top, 0));
    await _saveDps('driver_2', _formatDriver(top, 1));
    await _saveDps('driver_3', _formatDriver(top, 2));

    await HomeWidget.updateWidget(
      qualifiedAndroidName: androidQualifiedDriverWidgetProvider,
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
}
