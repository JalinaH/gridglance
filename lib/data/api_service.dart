import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/constructor_standing.dart';
import '../models/driver_standing.dart';
import '../models/race.dart';
import '../models/race_result.dart';
import '../models/season_overview.dart';

class ApiService {
  static const String _baseUrl = 'https://api.jolpi.ca/ergast/f1/';

  Future<List<DriverStanding>> getDriverStandings({String season = '2025'}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$season/driverstandings/'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final mrData = data['MRData'] as Map<String, dynamic>? ?? {};
      final standingsTable = mrData['StandingsTable'] as Map<String, dynamic>? ?? {};
      final standingsLists = standingsTable['StandingsLists'] as List? ?? [];
      if (standingsLists.isEmpty) {
        return [];
      }
      final standingsJson =
          standingsLists.first['DriverStandings'] as List? ?? [];

      return standingsJson
          .map((json) => DriverStanding.fromJson(json as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load standings');
    }
  }

  Future<List<ConstructorStanding>> getConstructorStandings({String season = '2025'}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$season/constructorstandings/'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final mrData = data['MRData'] as Map<String, dynamic>? ?? {};
      final standingsTable = mrData['StandingsTable'] as Map<String, dynamic>? ?? {};
      final standingsLists = standingsTable['StandingsLists'] as List? ?? [];
      if (standingsLists.isEmpty) {
        return [];
      }
      final standingsJson =
          standingsLists.first['ConstructorStandings'] as List? ?? [];

      return standingsJson
          .map((json) => ConstructorStanding.fromJson(json as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load team standings');
    }
  }

  Future<Race?> getNextRace({String season = '2025'}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$season/next/'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final mrData = data['MRData'] as Map<String, dynamic>? ?? {};
      final raceTable = mrData['RaceTable'] as Map<String, dynamic>? ?? {};
      final racesJson = raceTable['Races'] as List? ?? [];
      if (racesJson.isEmpty) {
        return null;
      }
      return Race.fromJson(racesJson.first as Map<String, dynamic>);
    } else {
      throw Exception('Failed to load next race');
    }
  }

  Future<List<Race>> getRaceSchedule({String season = '2025'}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$season/'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final mrData = data['MRData'] as Map<String, dynamic>? ?? {};
      final raceTable = mrData['RaceTable'] as Map<String, dynamic>? ?? {};
      final racesJson = raceTable['Races'] as List? ?? [];

      return racesJson
          .map((json) => Race.fromJson(json as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load race schedule');
    }
  }

  Future<SeasonOverview> getSeasonOverview({String season = '2025'}) async {
    final results = await Future.wait([
      getDriverStandings(season: season),
      getConstructorStandings(season: season),
      getNextRace(season: season),
      getRaceSchedule(season: season),
    ]);

    return SeasonOverview(
      driverStandings: results[0] as List<DriverStanding>,
      constructorStandings: results[1] as List<ConstructorStanding>,
      nextRace: results[2] as Race?,
      raceSchedule: results[3] as List<Race>,
    );
  }

  Future<List<DriverRaceResult>> getDriverResults({
    required String season,
    required String driverId,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$season/drivers/$driverId/results/'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final mrData = data['MRData'] as Map<String, dynamic>? ?? {};
      final raceTable = mrData['RaceTable'] as Map<String, dynamic>? ?? {};
      final racesJson = raceTable['Races'] as List? ?? [];
      return racesJson
          .map((json) => DriverRaceResult.fromRaceJson(json as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load driver results');
    }
  }

  Future<List<TeamRaceResult>> getConstructorResults({
    required String season,
    required String constructorId,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$season/constructors/$constructorId/results/'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final mrData = data['MRData'] as Map<String, dynamic>? ?? {};
      final raceTable = mrData['RaceTable'] as Map<String, dynamic>? ?? {};
      final racesJson = raceTable['Races'] as List? ?? [];
      return racesJson
          .map((json) => TeamRaceResult.fromRaceJson(json as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load constructor results');
    }
  }
}
