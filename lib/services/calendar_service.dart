import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/services.dart';
import '../models/race.dart';

class CalendarService {
  static Future<bool> addSessionToCalendar({
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
        ? startLocal.add(Duration(days: 1))
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

  static Duration _sessionDuration(RaceSession session) {
    final name = session.name.toLowerCase();
    if (name.contains('race')) {
      return Duration(hours: 2);
    }
    if (name.contains('sprint')) {
      return Duration(hours: 1);
    }
    if (name.contains('qualifying')) {
      return Duration(hours: 1, minutes: 30);
    }
    if (name.contains('practice')) {
      return Duration(hours: 1);
    }
    return Duration(hours: 2);
  }
}
