class Race {
  final String round;
  final String raceName;
  final String date;
  final String? time;
  final String circuitName;
  final String locality;
  final String country;

  Race({
    required this.round,
    required this.raceName,
    required this.date,
    required this.time,
    required this.circuitName,
    required this.locality,
    required this.country,
  });

  factory Race.fromJson(Map<String, dynamic> json) {
    final circuit = json['Circuit'] as Map<String, dynamic>? ?? {};
    final location = circuit['Location'] as Map<String, dynamic>? ?? {};

    return Race(
      round: json['round'] ?? '',
      raceName: json['raceName'] ?? '',
      date: json['date'] ?? '',
      time: json['time'],
      circuitName: circuit['circuitName'] ?? '',
      locality: location['locality'] ?? '',
      country: location['country'] ?? '',
    );
  }

  String get location {
    if (locality.isEmpty) {
      return country;
    }
    if (country.isEmpty) {
      return locality;
    }
    return '$locality, $country';
  }

  String get displayDateTime {
    if (time == null || time!.isEmpty) {
      return date;
    }
    return '$date $time';
  }
}
