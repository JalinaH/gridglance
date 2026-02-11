import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/race.dart';

class WeekendWeather {
  final WeatherCurrent? current;
  final List<WeatherDaily> daily;

  const WeekendWeather({required this.current, required this.daily});
}

class WeatherCurrent {
  final DateTime? time;
  final double? temperatureC;
  final double? windSpeedKph;
  final int? weatherCode;

  const WeatherCurrent({
    required this.time,
    required this.temperatureC,
    required this.windSpeedKph,
    required this.weatherCode,
  });
}

class WeatherDaily {
  final DateTime date;
  final double? highC;
  final double? lowC;
  final int? weatherCode;
  final int? precipitationChance;

  const WeatherDaily({
    required this.date,
    required this.highC,
    required this.lowC,
    required this.weatherCode,
    required this.precipitationChance,
  });
}

class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  Future<WeekendWeather?> getRaceWeekendWeather(Race race) async {
    final latitude = race.latitude;
    final longitude = race.longitude;
    if (latitude == null || longitude == null) {
      return null;
    }

    final sessions =
        race.sessions.where((session) => session.startDateTime != null).toList()
          ..sort((a, b) => a.startDateTime!.compareTo(b.startDateTime!));

    final first = sessions.isNotEmpty
        ? sessions.first.startDateTime!
        : race.startDateTime;
    final last = sessions.isNotEmpty
        ? sessions.last.startDateTime!
        : race.startDateTime;
    if (first == null || last == null) {
      return null;
    }

    final startDate = _isoDate(first.toUtc());
    final endDate = _isoDate(last.toUtc());
    final uri = Uri.parse(
      '$_baseUrl?latitude=$latitude&longitude=$longitude'
      '&current=temperature_2m,weather_code,wind_speed_10m'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max'
      '&start_date=$startDate&end_date=$endDate&timezone=auto',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load weather');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final current = _parseCurrent(data['current']);
    final daily = _parseDaily(data['daily']);
    return WeekendWeather(current: current, daily: daily);
  }

  static String labelForCode(int? code) {
    switch (code) {
      case 0:
        return 'Clear sky';
      case 1:
      case 2:
      case 3:
        return 'Partly cloudy';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return 'Rain';
      case 71:
      case 73:
      case 75:
      case 85:
      case 86:
        return 'Snow';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorm';
      default:
        return 'Conditions unavailable';
    }
  }

  static WeatherCurrent? _parseCurrent(dynamic value) {
    if (value is! Map) {
      return null;
    }
    final map = value.cast<String, dynamic>();
    return WeatherCurrent(
      time: DateTime.tryParse('${map['time'] ?? ''}'),
      temperatureC: _toDouble(map['temperature_2m']),
      windSpeedKph: _toDouble(map['wind_speed_10m']),
      weatherCode: _toInt(map['weather_code']),
    );
  }

  static List<WeatherDaily> _parseDaily(dynamic value) {
    if (value is! Map) {
      return const <WeatherDaily>[];
    }
    final map = value.cast<String, dynamic>();
    final dates = (map['time'] as List?) ?? const <dynamic>[];
    final highs = (map['temperature_2m_max'] as List?) ?? const <dynamic>[];
    final lows = (map['temperature_2m_min'] as List?) ?? const <dynamic>[];
    final codes = (map['weather_code'] as List?) ?? const <dynamic>[];
    final rainProbabilities =
        (map['precipitation_probability_max'] as List?) ?? const <dynamic>[];

    final count = dates.length;
    final weather = <WeatherDaily>[];
    for (var index = 0; index < count; index++) {
      final date = DateTime.tryParse('${dates[index]}');
      if (date == null) {
        continue;
      }
      weather.add(
        WeatherDaily(
          date: date,
          highC: _toDouble(index < highs.length ? highs[index] : null),
          lowC: _toDouble(index < lows.length ? lows[index] : null),
          weatherCode: _toInt(index < codes.length ? codes[index] : null),
          precipitationChance: _toInt(
            index < rainProbabilities.length ? rainProbabilities[index] : null,
          ),
        ),
      );
    }
    return weather;
  }

  static double? _toDouble(dynamic value) {
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

  static int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static String _isoDate(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
