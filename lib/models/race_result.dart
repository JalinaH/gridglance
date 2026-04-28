import '../utils/json_safe.dart';

class DriverRaceResult {
  final String round;
  final String raceName;
  final String date;
  final String position;
  final String points;
  final String status;

  const DriverRaceResult({
    required this.round,
    required this.raceName,
    required this.date,
    required this.position,
    required this.points,
    required this.status,
  });

  factory DriverRaceResult.fromRaceJson(Map<String, dynamic> json) {
    final reader = JsonReader(json);
    final result = reader.readers('Results').firstOrNull;
    return DriverRaceResult(
      round: reader.string('round'),
      raceName: reader.string('raceName'),
      date: reader.string('date'),
      position: result?.string('position', defaultValue: '-') ?? '-',
      points: result?.string('points', defaultValue: '0') ?? '0',
      status: result?.string('status') ?? '',
    );
  }
}

class TeamRaceResult {
  final String round;
  final String raceName;
  final String date;
  final List<TeamDriverResult> drivers;

  const TeamRaceResult({
    required this.round,
    required this.raceName,
    required this.date,
    required this.drivers,
  });

  factory TeamRaceResult.fromRaceJson(Map<String, dynamic> json) {
    final reader = JsonReader(json);
    return TeamRaceResult(
      round: reader.string('round'),
      raceName: reader.string('raceName'),
      date: reader.string('date'),
      drivers: reader
          .readers('Results')
          .map(_teamDriverFromReader)
          .toList(),
    );
  }
}

class TeamDriverResult {
  final String givenName;
  final String familyName;
  final String position;
  final String points;
  final String? code;
  final String? permanentNumber;

  const TeamDriverResult({
    required this.givenName,
    required this.familyName,
    required this.position,
    required this.points,
    required this.code,
    required this.permanentNumber,
  });

  factory TeamDriverResult.fromJson(Map<String, dynamic> json) =>
      _teamDriverFromReader(JsonReader(json));
}

TeamDriverResult _teamDriverFromReader(JsonReader reader) {
  final driver = reader.requireMap('Driver');
  return TeamDriverResult(
    givenName: driver.string('givenName'),
    familyName: driver.string('familyName'),
    position: reader.string('position', defaultValue: '-'),
    points: reader.string('points', defaultValue: '0'),
    code: driver.optString('code'),
    permanentNumber: driver.optString('permanentNumber'),
  );
}

class DriverSprintResult {
  final String round;
  final String raceName;
  final String date;
  final String points;

  const DriverSprintResult({
    required this.round,
    required this.raceName,
    required this.date,
    required this.points,
  });

  factory DriverSprintResult.fromRaceJson(Map<String, dynamic> json) {
    final reader = JsonReader(json);
    final result = reader.readers('SprintResults').firstOrNull;
    return DriverSprintResult(
      round: reader.string('round'),
      raceName: reader.string('raceName'),
      date: reader.string('date'),
      points: result?.string('points', defaultValue: '0') ?? '0',
    );
  }
}

class TeamSprintResult {
  final String round;
  final String raceName;
  final String date;
  final List<String> points;

  const TeamSprintResult({
    required this.round,
    required this.raceName,
    required this.date,
    required this.points,
  });

  factory TeamSprintResult.fromRaceJson(Map<String, dynamic> json) {
    final reader = JsonReader(json);
    return TeamSprintResult(
      round: reader.string('round'),
      raceName: reader.string('raceName'),
      date: reader.string('date'),
      points: reader
          .readers('SprintResults')
          .map((r) => r.string('points', defaultValue: '0'))
          .toList(),
    );
  }
}

class DriverQualifyingResult {
  final String round;
  final String raceName;
  final String date;
  final String position;

  const DriverQualifyingResult({
    required this.round,
    required this.raceName,
    required this.date,
    required this.position,
  });

  factory DriverQualifyingResult.fromRaceJson(Map<String, dynamic> json) {
    final reader = JsonReader(json);
    final result = reader.readers('QualifyingResults').firstOrNull;
    return DriverQualifyingResult(
      round: reader.string('round'),
      raceName: reader.string('raceName'),
      date: reader.string('date'),
      position: result?.string('position', defaultValue: '-') ?? '-',
    );
  }
}

class TeamQualifyingResult {
  final String round;
  final String raceName;
  final String date;
  final List<String> positions;

  const TeamQualifyingResult({
    required this.round,
    required this.raceName,
    required this.date,
    required this.positions,
  });

  factory TeamQualifyingResult.fromRaceJson(Map<String, dynamic> json) {
    final reader = JsonReader(json);
    return TeamQualifyingResult(
      round: reader.string('round'),
      raceName: reader.string('raceName'),
      date: reader.string('date'),
      positions: reader
          .readers('QualifyingResults')
          .map((r) => r.string('position', defaultValue: '-'))
          .toList(),
    );
  }
}
