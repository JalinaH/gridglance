import 'dart:async';

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/services.dart';
import '../models/race.dart';
import 'analytics.dart';

class CalendarImportResult {
  final int added;
  final int total;

  const CalendarImportResult({required this.added, required this.total});

  int get failed => total - added;
}

class CalendarService {
  static Future<bool> addSessionToCalendar({
    required Race race,
    required RaceSession session,
    required String season,
  }) async {
    final added = await _addSession(
      race: race,
      session: session,
      season: season,
    );
    if (added) {
      unawaited(
        Analytics.track(
          'calendar_exported',
          properties: {'kind': 'session', 'session_type': session.name},
        ),
      );
    }
    return added;
  }

  static Future<bool> _addSession({
    required Race race,
    required RaceSession session,
    required String season,
  }) async {
    final start = session.startDateTime;
    if (start == null) {
      return false;
    }
    final isAllDay = session.time == null || session.time!.isEmpty;
    final startLocal = start.toLocal();
    final end = isAllDay
        ? startLocal.add(const Duration(days: 1))
        : startLocal.add(_sessionDuration(session));
    final event = Event(
      title: '${race.raceName} - ${session.name}',
      description: 'Season $season • Round ${race.round}',
      location: '${race.circuitName}, ${race.location}',
      startDate: startLocal,
      endDate: end,
      allDay: isAllDay,
    );
    try {
      await Add2Calendar.addEvent2Cal(event);
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<CalendarImportResult> addRaceWeekendToCalendar({
    required Race race,
    required String season,
  }) async {
    final sessions =
        race.sessions.where((session) => session.startDateTime != null).toList()
          ..sort((a, b) => a.startDateTime!.compareTo(b.startDateTime!));

    var added = 0;
    for (final session in sessions) {
      final success = await _addSession(
        race: race,
        session: session,
        season: season,
      );
      if (success) {
        added += 1;
      }
    }
    unawaited(
      Analytics.track(
        'calendar_exported',
        properties: {
          'kind': 'weekend',
          'sessions_added': added,
          'sessions_total': sessions.length,
        },
      ),
    );
    return CalendarImportResult(added: added, total: sessions.length);
  }

  static Duration _sessionDuration(RaceSession session) {
    final name = session.name.toLowerCase();
    if (name.contains('race')) {
      return const Duration(hours: 2);
    }
    if (name.contains('sprint')) {
      return const Duration(hours: 1);
    }
    if (name.contains('qualifying')) {
      return const Duration(hours: 1, minutes: 30);
    }
    if (name.contains('practice')) {
      return const Duration(hours: 1);
    }
    return const Duration(hours: 2);
  }
}
