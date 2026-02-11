class Race {
  final String round;
  final String raceName;
  final String date;
  final String? time;
  final String circuitName;
  final String locality;
  final String country;
  final double? latitude;
  final double? longitude;
  final RaceSession? practice1;
  final RaceSession? practice2;
  final RaceSession? practice3;
  final RaceSession? qualifying;
  final RaceSession? sprintQualifying;
  final RaceSession? sprint;

  Race({
    required this.round,
    required this.raceName,
    required this.date,
    required this.time,
    required this.circuitName,
    required this.locality,
    required this.country,
    this.latitude,
    this.longitude,
    required this.practice1,
    required this.practice2,
    required this.practice3,
    required this.qualifying,
    required this.sprintQualifying,
    required this.sprint,
  });

  factory Race.fromJson(Map<String, dynamic> json) {
    final circuit = json['Circuit'] as Map<String, dynamic>? ?? {};
    final location = circuit['Location'] as Map<String, dynamic>? ?? {};
    final sessions = _parseSessions(json);

    return Race(
      round: json['round'] ?? '',
      raceName: json['raceName'] ?? '',
      date: json['date'] ?? '',
      time: json['time'],
      circuitName: circuit['circuitName'] ?? '',
      locality: location['locality'] ?? '',
      country: location['country'] ?? '',
      latitude: _parseCoordinate(location['lat']),
      longitude: _parseCoordinate(location['long']),
      practice1: sessions['practice1'],
      practice2: sessions['practice2'],
      practice3: sessions['practice3'],
      qualifying: sessions['qualifying'],
      sprintQualifying: sessions['sprintQualifying'],
      sprint: sessions['sprint'],
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

  DateTime? get startDateTime => _parseDateTime(date, time);

  RaceSession get raceSession =>
      RaceSession(name: 'Race', date: date, time: time);

  List<RaceSession> get sessions {
    return [
      if (practice1 != null) practice1!,
      if (practice2 != null) practice2!,
      if (practice3 != null) practice3!,
      if (qualifying != null) qualifying!,
      if (sprintQualifying != null) sprintQualifying!,
      if (sprint != null) sprint!,
      raceSession,
    ];
  }

  static Map<String, RaceSession?> _parseSessions(Map<String, dynamic> json) {
    return {
      'practice1': _parseSession(json, 'FirstPractice', 'Free Practice 1'),
      'practice2': _parseSession(json, 'SecondPractice', 'Free Practice 2'),
      'practice3': _parseSession(json, 'ThirdPractice', 'Free Practice 3'),
      'qualifying': _parseSession(json, 'Qualifying', 'Qualifying'),
      'sprintQualifying': _parseSession(
        json,
        'SprintQualifying',
        'Sprint Qualifying',
      ),
      'sprint': _parseSession(json, 'Sprint', 'Sprint'),
    };
  }

  static RaceSession? _parseSession(
    Map<String, dynamic> json,
    String key,
    String label,
  ) {
    final data = json[key] as Map<String, dynamic>?;
    if (data == null) {
      return null;
    }
    return RaceSession(
      name: label,
      date: data['date'] ?? '',
      time: data['time'],
    );
  }
}

class RaceSession {
  final String name;
  final String date;
  final String? time;

  RaceSession({required this.name, required this.date, required this.time});

  String get displayDateTime {
    if (time == null || time!.isEmpty) {
      return date;
    }
    return '$date $time';
  }

  DateTime? get startDateTime => _parseDateTime(date, time);
}

DateTime? _parseDateTime(String date, String? time) {
  if (date.isEmpty) {
    return null;
  }
  if (time == null || time.isEmpty) {
    return DateTime.tryParse(date);
  }
  final normalizedTime = time.startsWith('T') ? time.substring(1) : time;
  return DateTime.tryParse('${date}T$normalizedTime');
}

double? _parseCoordinate(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}
