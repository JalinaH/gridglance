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
    final reader = JsonReader(json);
    final team = reader.readers('Constructors').firstOrNull;
    final driver = reader.requireMap('Driver');

    return DriverStanding(
      position: reader.string('position', defaultValue: '-'),
      points: reader.string('points', defaultValue: '0'),
      wins: reader.string('wins', defaultValue: '0'),
      givenName: driver.string('givenName'),
      familyName: driver.string('familyName'),
      teamName: team?.string('name') ?? '',
      driverId: driver.string('driverId'),
      constructorId: team?.string('constructorId') ?? '',
      code: driver.optString('code'),
      permanentNumber: driver.optString('permanentNumber'),
      nationality: driver.optString('nationality'),
    );
  }
}
