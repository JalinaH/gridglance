class DriverStanding {
  final String position;
  final String points;
  final String wins;
  final String givenName;
  final String familyName;
  final String teamName;

  DriverStanding({
    required this.position,
    required this.points,
    required this.wins,
    required this.givenName,
    required this.familyName,
    required this.teamName,
  });

  factory DriverStanding.fromJson(Map<String, dynamic> json) {
    final constructors = json['Constructors'] as List? ?? [];
    final team = constructors.isNotEmpty ? constructors[0] as Map<String, dynamic>? : null;

    return DriverStanding(
      position: json['position'] ?? '-',
      points: json['points'] ?? '0',
      wins: json['wins'] ?? '0',
      givenName: json['Driver']?['givenName'] ?? '',
      familyName: json['Driver']?['familyName'] ?? '',
      teamName: team?['name'] ?? '',
    );
  }
}
