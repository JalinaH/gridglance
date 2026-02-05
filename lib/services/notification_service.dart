import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/race.dart';

enum ScheduleResult {
  scheduled,
  missingTime,
  inPast,
  permissionDenied,
  unavailable,
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static String? _lastError;

  static String? get lastError => _lastError;

  static Future<ScheduleResult> _scheduleZoned({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required NotificationDetails details,
    required bool preferExact,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: preferExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return ScheduleResult.scheduled;
    } on PlatformException catch (error) {
      final code = error.code.toLowerCase();
      if (preferExact && code.contains('exact_alarms_not_permitted')) {
        _lastError = 'Exact alarms not permitted; scheduled inexact (may delay).';
        return _scheduleZoned(
          id: id,
          title: title,
          body: body,
          scheduledTime: scheduledTime,
          details: details,
          preferExact: false,
        );
      }
      _lastError = 'Platform error: ${error.code} ${error.message ?? ''}'.trim();
      return ScheduleResult.unavailable;
    } on MissingPluginException catch (error) {
      _lastError = 'Missing plugin: $error';
      return ScheduleResult.unavailable;
    } catch (error) {
      _lastError = 'Unexpected error: $error';
      return ScheduleResult.unavailable;
    }
  }

  static Future<void> scheduleRaceWeekend({
    required Race race,
    required String season,
    Duration leadTime = const Duration(minutes: 15),
  }) async {
    await init();
    final allowed = await requestPermissions();
    if (!allowed) {
      _lastError = 'Permissions denied';
      return;
    }
    for (final session in race.sessions) {
      if (session.startDateTime == null ||
          session.time == null ||
          session.time!.isEmpty) {
        continue;
      }
      final scheduledTime = session.startDateTime!.toLocal().subtract(leadTime);
      if (scheduledTime.isBefore(DateTime.now())) {
        continue;
      }
      final id = notificationIdForSession(
        race: race,
        session: session,
        season: season,
      );
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'session_start',
          'Session start',
          channelDescription: 'Race session start reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      );
      await _scheduleZoned(
        id: id,
        title: '${race.raceName} • ${session.name}',
        body: 'Session starts in ${leadTime.inMinutes} minutes',
        scheduledTime: scheduledTime,
        details: details,
        preferExact: true,
      );
    }
  }

  static Future<void> init() async {
    if (_initialized) {
      return;
    }
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.local);
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSSettings = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: androidSettings, iOS: iOSSettings);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<bool> requestPermissions() async {
    var granted = true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final ok = await android.requestNotificationsPermission();
      if (ok == false) {
        granted = false;
      }
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final ok = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (ok == false) {
        granted = false;
      }
    }

    return granted;
  }

  static Future<ScheduleResult> scheduleSessionNotification({
    required Race race,
    required RaceSession session,
    required String season,
    Duration leadTime = const Duration(minutes: 15),
  }) async {
    await init();
    final start = session.startDateTime;
    if (start == null) {
      return ScheduleResult.missingTime;
    }
    final scheduledTime = start.toLocal().subtract(leadTime);
    if (scheduledTime.isBefore(DateTime.now())) {
      return ScheduleResult.inPast;
    }

    final allowed = await requestPermissions();
    if (!allowed) {
      return ScheduleResult.permissionDenied;
    }

    final id = notificationIdForSession(
      race: race,
      session: session,
      season: season,
    );
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'session_start',
        'Session start',
        channelDescription: 'Race session start reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        '${race.raceName} • ${session.name}',
        'Session starts in ${leadTime.inMinutes} minutes',
        tz.TZDateTime.from(scheduledTime, tz.local),
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return ScheduleResult.scheduled;
    } on MissingPluginException catch (error) {
      _lastError = 'Missing plugin: $error';
      return ScheduleResult.unavailable;
    } on PlatformException catch (error) {
      _lastError = 'Platform error: ${error.code} ${error.message ?? ''}'.trim();
      return ScheduleResult.unavailable;
    } catch (error) {
      _lastError = 'Unexpected error: $error';
      return ScheduleResult.unavailable;
    }
  }

  static Future<void> cancelSessionNotification({
    required Race race,
    required RaceSession session,
    required String season,
  }) async {
    await init();
    final id = notificationIdForSession(
      race: race,
      session: session,
      season: season,
    );
    await _plugin.cancel(id);
  }

  static int notificationIdForSession({
    required Race race,
    required RaceSession session,
    required String season,
  }) {
    final key = sessionKey(race: race, session: session, season: season);
    return _stableHash(key);
  }

  static String sessionKey({
    required Race race,
    required RaceSession session,
    required String season,
  }) {
    final raw = [
      season,
      race.round,
      session.name,
      session.date,
      session.time ?? '',
    ].join('|');
    return base64Url.encode(utf8.encode(raw));
  }

  static int _stableHash(String input) {
    var hash = 0x811c9dc5;
    for (final code in input.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7fffffff;
  }
}
