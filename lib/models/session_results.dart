import 'race.dart';

enum SessionType { race, qualifying, sprint }

class SessionResults {
  final Race race;
  final List<ResultEntry> results;
  final SessionType type;

  const SessionResults({
    required this.race,
    required this.results,
    required this.type,
  });
}

class ResultEntry {
  final String position;
  final String driverName;
  final String teamName;
  final String points;
  final String status;
  final String? time;
  final String? q1;
  final String? q2;
  final String? q3;

  const ResultEntry({
    required this.position,
    required this.driverName,
    required this.teamName,
    required this.points,
    required this.status,
    required this.time,
    required this.q1,
    required this.q2,
    required this.q3,
  });

  factory ResultEntry.fromJson(Map<String, dynamic> json,
      {required SessionType type}) {
    final driver = json['Driver'] as Map<String, dynamic>? ?? {};
    final constructor = json['Constructor'] as Map<String, dynamic>? ?? {};
    final timeData = json['Time'] as Map<String, dynamic>?;
    final status = json['status'] ?? '';
    final time = timeData?['time'] as String?;
    return ResultEntry(
      position: json['position'] ?? '-',
      driverName:
          '${driver['givenName'] ?? ''} ${driver['familyName'] ?? ''}'.trim(),
      teamName: constructor['name'] ?? '',
      points: json['points'] ?? '',
      status: status ?? '',
      time: time,
      q1: type == SessionType.qualifying ? json['Q1'] : null,
      q2: type == SessionType.qualifying ? json['Q2'] : null,
      q3: type == SessionType.qualifying ? json['Q3'] : null,
    );
  }

  String get timeOrStatus {
    if (time != null && time!.isNotEmpty) {
      return time!;
    }
    return status;
  }
}
