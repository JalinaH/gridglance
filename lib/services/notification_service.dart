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
  static const Duration _minimumScheduleOffset = Duration(minutes: 1);

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
        _lastError =
            'Exact alarms not permitted; scheduled inexact (may delay).';
        return _scheduleZoned(
          id: id,
          title: title,
          body: body,
          scheduledTime: scheduledTime,
          details: details,
          preferExact: false,
        );
      }
      _lastError = 'Platform error: ${error.code} ${error.message ?? ''}'
          .trim();
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

  static Future<ScheduleResult> scheduleWeekendDigest({
    required Race race,
    required String season,
  }) async {
    await init();
    final timedSessions = _timedFutureSessions(race);
    if (timedSessions.isEmpty) {
      return ScheduleResult.inPast;
    }
    final firstSessionStart = timedSessions.first.startDateTime!;
    final now = DateTime.now();
    final desiredTime = firstSessionStart.toLocal().subtract(
      const Duration(hours: 24),
    );
    final fallback = now.add(_minimumScheduleOffset);
    final scheduledTime = desiredTime.isAfter(fallback)
        ? desiredTime
        : fallback;

    final allowed = await requestPermissions();
    if (!allowed) {
      return ScheduleResult.permissionDenied;
    }

    final id = notificationIdForWeekendDigest(race: race, season: season);
    return _scheduleZoned(
      id: id,
      title: '${race.raceName} weekend digest',
      body: _buildWeekendDigestBody(timedSessions),
      scheduledTime: scheduledTime,
      details: _weekendDigestNotificationDetails(),
      preferExact: false,
    );
  }

  static Future<void> init() async {
    if (_initialized) {
      return;
    }
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.local);
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iOSSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<bool> requestPermissions() async {
    var granted = true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final ok = await android.requestNotificationsPermission();
      if (ok == false) {
        granted = false;
      }
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
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
    return _scheduleZoned(
      id: id,
      title: '${race.raceName} • ${session.name}',
      body: 'Session starts in ${_leadTimeLabel(leadTime)}',
      scheduledTime: scheduledTime,
      details: details,
      preferExact: true,
    );
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

  static Future<void> cancelWeekendDigestNotification({
    required Race race,
    required String season,
  }) async {
    await init();
    final id = notificationIdForWeekendDigest(race: race, season: season);
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

  static int notificationIdForWeekendDigest({
    required Race race,
    required String season,
  }) {
    final key = weekendDigestKey(race: race, season: season);
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

  static String weekendDigestKey({required Race race, required String season}) {
    final raw = [
      'digest',
      season,
      race.round,
      race.raceName,
      race.date,
      race.time ?? '',
    ].join('|');
    return base64Url.encode(utf8.encode(raw));
  }

  static NotificationDetails _weekendDigestNotificationDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'weekend_digest',
        'Weekend digest',
        channelDescription: 'Race weekend summary reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  static List<RaceSession> _timedFutureSessions(Race race) {
    final now = DateTime.now();
    final sessions = race.sessions
        .where(
          (session) =>
              session.startDateTime != null &&
              session.time != null &&
              session.time!.isNotEmpty &&
              session.startDateTime!.isAfter(now),
        )
        .toList();
    sessions.sort((a, b) => a.startDateTime!.compareTo(b.startDateTime!));
    return sessions;
  }

  static String _buildWeekendDigestBody(List<RaceSession> sessions) {
    final preview = sessions.take(3).map((session) => session.name).join(', ');
    if (preview.isEmpty) {
      return 'Your race weekend starts soon.';
    }
    if (sessions.length > 3) {
      return 'Upcoming sessions: $preview, and more.';
    }
    return 'Upcoming sessions: $preview.';
  }

  static String _leadTimeLabel(Duration leadTime) {
    final minutes = leadTime.inMinutes;
    if (minutes == 60) {
      return '1 hour';
    }
    if (minutes == 1440) {
      return '24 hours';
    }
    if (minutes >= 60 && minutes % 60 == 0) {
      return '${minutes ~/ 60} hours';
    }
    return '$minutes minutes';
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
