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
    final constructor = json['Constructor'] as Map<String, dynamic>? ?? {};

    return ConstructorStanding(
      position: json['position'] ?? '-',
      points: json['points'] ?? '0',
      wins: json['wins'] ?? '0',
      teamName: constructor['name'] ?? '',
      constructorId: constructor['constructorId'] ?? '',
    );
  }
}
