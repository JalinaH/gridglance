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
    final results = json['Results'] as List? ?? [];
    final result = results.isNotEmpty
        ? results.first as Map<String, dynamic>? ?? {}
        : <String, dynamic>{};
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
    final results = json['Results'] as List? ?? [];
    return TeamRaceResult(
      round: json['round'] ?? '',
      raceName: json['raceName'] ?? '',
      date: json['date'] ?? '',
      drivers: results
          .map(
            (item) => TeamDriverResult.fromJson(item as Map<String, dynamic>),
          )
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
    final driver = json['Driver'] as Map<String, dynamic>? ?? {};
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
    final sprintResults = json['SprintResults'] as List? ?? [];
    final result = sprintResults.isNotEmpty
        ? sprintResults.first as Map<String, dynamic>? ?? {}
        : <String, dynamic>{};
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
    final sprintResults = json['SprintResults'] as List? ?? [];
    final points = sprintResults
        .map((item) => '${(item as Map<String, dynamic>)['points'] ?? '0'}')
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
    final qualifying = json['QualifyingResults'] as List? ?? [];
    final result = qualifying.isNotEmpty
        ? qualifying.first as Map<String, dynamic>? ?? {}
        : <String, dynamic>{};
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
    final qualifying = json['QualifyingResults'] as List? ?? [];
    final positions = qualifying
        .map((item) => '${(item as Map<String, dynamic>)['position'] ?? '-'}')
        .toList();
    return TeamQualifyingResult(
      round: json['round'] ?? '',
      raceName: json['raceName'] ?? '',
      date: json['date'] ?? '',
      positions: positions,
    );
  }
}
