import 'dart:convert';

import '../models/session_results.dart';

/// Where a tap on one of the app's notifications should take the user.
enum NotificationDestination {
  /// A race weekend: session reminders and the weekend digest.
  race,

  /// Results of the latest session: "session finished" alerts.
  sessionResults,

  /// A driver's detail screen: favorite driver standings alerts.
  driver,

  /// A team's detail screen: favorite team standings alerts.
  team,
}

/// The payload attached to a notification, so a tap can open the screen the
/// notification is about instead of the home tab.
///
/// Encoded as a small JSON string in the notification's `payload`. Anything
/// malformed or from an older or newer build decodes to null, and the tap
/// then just opens the app.
class NotificationTarget {
  final NotificationDestination destination;
  final String season;

  /// Round for [NotificationDestination.race].
  final String? round;

  /// `driverId` or `constructorId` for driver and team destinations.
  final String? id;

  /// Session tab to open for [NotificationDestination.sessionResults].
  final SessionType? session;

  const NotificationTarget._({
    required this.destination,
    required this.season,
    this.round,
    this.id,
    this.session,
  });

  const NotificationTarget.race({required String season, required String round})
    : this._(
        destination: NotificationDestination.race,
        season: season,
        round: round,
      );

  const NotificationTarget.sessionResults({
    required String season,
    required SessionType session,
  }) : this._(
         destination: NotificationDestination.sessionResults,
         season: season,
         session: session,
       );

  const NotificationTarget.driver({
    required String season,
    required String driverId,
  }) : this._(
         destination: NotificationDestination.driver,
         season: season,
         id: driverId,
       );

  const NotificationTarget.team({
    required String season,
    required String constructorId,
  }) : this._(
         destination: NotificationDestination.team,
         season: season,
         id: constructorId,
       );

  static const int _version = 1;

  String encode() => jsonEncode({
    'v': _version,
    'to': destination.name,
    'season': season,
    if (round != null) 'round': round,
    if (id != null) 'id': id,
    if (session != null) 'session': session!.name,
  });

  /// Returns null for an empty, malformed or unknown payload.
  static NotificationTarget? decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    final Object? json;
    try {
      json = jsonDecode(payload);
    } on FormatException {
      return null;
    }
    if (json is! Map || json['v'] != _version) return null;
    final map = json;

    String? text(String key) {
      final value = map[key];
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final season = text('season');
    if (season == null) return null;
    switch (text('to')) {
      case 'race':
        final round = text('round');
        return round == null
            ? null
            : NotificationTarget.race(season: season, round: round);
      case 'sessionResults':
        final name = text('session');
        final session = SessionType.values
            .where((type) => type.name == name)
            .firstOrNull;
        return session == null
            ? null
            : NotificationTarget.sessionResults(
                season: season,
                session: session,
              );
      case 'driver':
        final id = text('id');
        return id == null
            ? null
            : NotificationTarget.driver(season: season, driverId: id);
      case 'team':
        final id = text('id');
        return id == null
            ? null
            : NotificationTarget.team(season: season, constructorId: id);
      default:
        return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationTarget &&
      other.destination == destination &&
      other.season == season &&
      other.round == round &&
      other.id == id &&
      other.session == session;

  @override
  int get hashCode => Object.hash(destination, season, round, id, session);

  @override
  String toString() => 'NotificationTarget(${encode()})';
}
