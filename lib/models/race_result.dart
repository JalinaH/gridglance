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
    final results = JsonSafe.asList(json['Results']);
    final result = results.isNotEmpty
        ? JsonSafe.asMap(results.first)
        : const <String, dynamic>{};
    return DriverRaceResult(
      round: json['round'] ?? '',
      raceName: json['raceName'] ?? '',
      date: json['date'] ?? '',
      position: result['position'] ?? '-',
      points: result['points'] ?? '0',
      status: result['status'] ?? '',
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
    final results = JsonSafe.asList(json['Results']);
    return TeamRaceResult(
      round: json['round'] ?? '',
      raceName: json['raceName'] ?? '',
      date: json['date'] ?? '',
      drivers: results
          .map((item) => JsonSafe.asMapOrNull(item))
          .whereType<Map<String, dynamic>>()
          .map(TeamDriverResult.fromJson)
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

  factory TeamDriverResult.fromJson(Map<String, dynamic> json) {
    final driver = JsonSafe.asMap(json['Driver']);
    return TeamDriverResult(
      givenName: driver['givenName'] ?? '',
      familyName: driver['familyName'] ?? '',
      position: json['position'] ?? '-',
      points: json['points'] ?? '0',
      code: driver['code'],
      permanentNumber: driver['permanentNumber'],
    );
  }
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
    final sprintResults = JsonSafe.asList(json['SprintResults']);
    final result = sprintResults.isNotEmpty
        ? JsonSafe.asMap(sprintResults.first)
        : const <String, dynamic>{};
    return DriverSprintResult(
      round: json['round'] ?? '',
      raceName: json['raceName'] ?? '',
      date: json['date'] ?? '',
      points: result['points'] ?? '0',
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
    final sprintResults = JsonSafe.asList(json['SprintResults']);
    final points = sprintResults
        .map((item) => '${JsonSafe.asMap(item)['points'] ?? '0'}')
        .toList();
    return TeamSprintResult(
      round: json['round'] ?? '',
      raceName: json['raceName'] ?? '',
      date: json['date'] ?? '',
      points: points,
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
    final qualifying = JsonSafe.asList(json['QualifyingResults']);
    final result = qualifying.isNotEmpty
        ? JsonSafe.asMap(qualifying.first)
        : const <String, dynamic>{};
    return DriverQualifyingResult(
      round: json['round'] ?? '',
      raceName: json['raceName'] ?? '',
      date: json['date'] ?? '',
      position: result['position'] ?? '-',
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
    final qualifying = JsonSafe.asList(json['QualifyingResults']);
    final positions = qualifying
        .map((item) => '${JsonSafe.asMap(item)['position'] ?? '-'}')
        .toList();
    return TeamQualifyingResult(
      round: json['round'] ?? '',
      raceName: json['raceName'] ?? '',
      date: json['date'] ?? '',
      positions: positions,
    );
  }
}
