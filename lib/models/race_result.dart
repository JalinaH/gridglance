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
          .map((item) => TeamDriverResult.fromJson(item as Map<String, dynamic>))
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
