import '../utils/json_safe.dart';

class ConstructorStanding {
  final String position;
  final String points;
  final String wins;
  final String teamName;
  final String constructorId;

  ConstructorStanding({
    required this.position,
    required this.points,
    required this.wins,
    required this.teamName,
    required this.constructorId,
  });

  factory ConstructorStanding.fromJson(Map<String, dynamic> json) {
    final reader = JsonReader(json);
    final constructor = reader.requireMap('Constructor');

    return ConstructorStanding(
      position: reader.string('position', defaultValue: '-'),
      points: reader.string('points', defaultValue: '0'),
      wins: reader.string('wins', defaultValue: '0'),
      teamName: constructor.string('name'),
      constructorId: constructor.string('constructorId'),
    );
  }
}
