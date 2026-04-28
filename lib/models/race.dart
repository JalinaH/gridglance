import '../utils/json_safe.dart';

class Race {
  final String round;
  final String raceName;
  final String date;
  final String? time;
  final String circuitId;
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
    required this.circuitId,
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
    final reader = JsonReader(json);
    final circuit = reader.requireMap('Circuit');
    final location = circuit.requireMap('Location');

    return Race(
      round: reader.string('round'),
      raceName: reader.string('raceName'),
      date: reader.string('date'),
      time: reader.optString('time'),
      circuitId: circuit.string('circuitId'),
      circuitName: circuit.string('circuitName'),
      locality: location.string('locality'),
      country: location.string('country'),
      latitude: location.optDouble('lat'),
      longitude: location.optDouble('long'),
      practice1: _parseSession(reader, 'FirstPractice', 'Free Practice 1'),
      practice2: _parseSession(reader, 'SecondPractice', 'Free Practice 2'),
      practice3: _parseSession(reader, 'ThirdPractice', 'Free Practice 3'),
      qualifying: _parseSession(reader, 'Qualifying', 'Qualifying'),
      sprintQualifying: _parseSession(
        reader,
        'SprintQualifying',
        'Sprint Qualifying',
      ),
      sprint: _parseSession(reader, 'Sprint', 'Sprint'),
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

  static RaceSession? _parseSession(
    JsonReader reader,
    String key,
    String label,
  ) {
    final data = reader.optMap(key);
    if (data == null) {
      return null;
    }
    return RaceSession(
      name: label,
      date: data.string('date'),
      time: data.optString('time'),
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

