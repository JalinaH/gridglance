class DriverStanding {
  final String position;
  final String points;
  final String wins;
  final String givenName;
  final String familyName;
  final String teamName;
  final String driverId;
  final String constructorId;
  final String? code;
  final String? permanentNumber;

  DriverStanding({
    required this.position,
    required this.points,
    required this.wins,
    required this.givenName,
    required this.familyName,
    required this.teamName,
    required this.driverId,
    required this.constructorId,
    required this.code,
    required this.permanentNumber,
  });

  factory DriverStanding.fromJson(Map<String, dynamic> json) {
    final constructors = json['Constructors'] as List? ?? [];
    final team = constructors.isNotEmpty ? constructors[0] as Map<String, dynamic>? : null;
    final driver = json['Driver'] as Map<String, dynamic>? ?? {};

    return DriverStanding(
      position: json['position'] ?? '-',
      points: json['points'] ?? '0',
      wins: json['wins'] ?? '0',
      givenName: driver['givenName'] ?? '',
      familyName: driver['familyName'] ?? '',
      teamName: team?['name'] ?? '',
      driverId: driver['driverId'] ?? '',
      constructorId: team?['constructorId'] ?? '',
      code: driver['code'],
      permanentNumber: driver['permanentNumber'],
    );
  }
}
