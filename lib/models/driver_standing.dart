import '../utils/json_safe.dart';

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
  final String? nationality;

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
    this.nationality,
  });

  factory DriverStanding.fromJson(Map<String, dynamic> json) {
    final constructors = JsonSafe.asList(json['Constructors']);
    final team = constructors.isNotEmpty
        ? JsonSafe.asMapOrNull(constructors[0])
        : null;
    final driver = JsonSafe.asMap(json['Driver']);

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
      nationality: driver['nationality'],
    );
  }
}
