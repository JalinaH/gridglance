class ConstructorStanding {
  final String position;
  final String points;
  final String wins;
  final String teamName;

  ConstructorStanding({
    required this.position,
    required this.points,
    required this.wins,
    required this.teamName,
  });

  factory ConstructorStanding.fromJson(Map<String, dynamic> json) {
    final constructor = json['Constructor'] as Map<String, dynamic>? ?? {};

    return ConstructorStanding(
      position: json['position'] ?? '-',
      points: json['points'] ?? '0',
      wins: json['wins'] ?? '0',
      teamName: constructor['name'] ?? '',
    );
  }
}
