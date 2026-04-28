import '../utils/json_safe.dart';
import 'race.dart';

enum SessionType { race, qualifying, sprint }

class SessionResults {
  final Race race;
  final List<ResultEntry> results;
  final SessionType type;
  final DateTime? lastUpdated;
  final bool isFromCache;

  const SessionResults({
    required this.race,
    required this.results,
    required this.type,
    this.lastUpdated,
    this.isFromCache = false,
  });
}

class ResultEntry {
  final String position;
  final String driverName;
  final String driverId;
  final String teamName;
  final String constructorId;
  final String points;
  final String status;
  final String? time;
  final String? q1;
  final String? q2;
  final String? q3;

  const ResultEntry({
    required this.position,
    required this.driverName,
    required this.driverId,
    required this.teamName,
    required this.constructorId,
    required this.points,
    required this.status,
    required this.time,
    required this.q1,
    required this.q2,
    required this.q3,
  });

  factory ResultEntry.fromJson(
    Map<String, dynamic> json, {
    required SessionType type,
  }) {
    final reader = JsonReader(json);
    final driver = reader.requireMap('Driver');
    final constructor = reader.requireMap('Constructor');
    final isQualifying = type == SessionType.qualifying;
    return ResultEntry(
      position: reader.string('position', defaultValue: '-'),
      driverName: '${driver.string('givenName')} ${driver.string('familyName')}'
          .trim(),
      driverId: driver.string('driverId'),
      teamName: constructor.string('name'),
      constructorId: constructor.string('constructorId'),
      points: reader.string('points'),
      status: reader.string('status'),
      time: reader.optMap('Time')?.optString('time'),
      q1: isQualifying ? reader.optString('Q1') : null,
      q2: isQualifying ? reader.optString('Q2') : null,
      q3: isQualifying ? reader.optString('Q3') : null,
    );
  }

  String get timeOrStatus {
    if (time != null && time!.isNotEmpty) {
      return time!;
    }
    return status;
  }
}
