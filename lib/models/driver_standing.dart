class DriverStanding {
  final String position;
  final String points;
  final String givenName;
  final String familyName;
  final String teamName;

  DriverStanding({
    required this.position,
    required this.points,
    required this.givenName,
    required this.familyName,
    required this.teamName,
  });

  factory DriverStanding.fromJson(Map<String, dynamic> json) {
    return DriverStanding(
      position: json['position'],
      points: json['points'],
      givenName: json['Driver']['givenName'],
      familyName: json['Driver']['familyName'],
      teamName: json['Constructors'][0]['name'],
    );
  }
}
