import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/constructor_standing.dart';
import '../models/driver_standing.dart';
import '../models/race.dart';
import '../models/race_result.dart';
import '../models/session_results.dart';
import '../models/season_overview.dart';

class CachedApiResponse<T> {
  final T data;
  final DateTime? lastUpdated;
  final bool isFromCache;

  const CachedApiResponse({
    required this.data,
    required this.lastUpdated,
    required this.isFromCache,
  });
}

class _CachedBody {
  final String body;
  final DateTime? updatedAt;

  const _CachedBody({required this.body, required this.updatedAt});
}

class ApiService {
  static const String _baseUrl = 'https://api.jolpi.ca/ergast/f1/';
  static const String _cacheNamespace = 'api_cache_v1';

  Future<List<DriverStanding>> getDriverStandings({
    String season = '2025',
  }) async {
    final snapshot = await getDriverStandingsSnapshot(season: season);
    return snapshot.data;
  }

  Future<CachedApiResponse<List<DriverStanding>>> getDriverStandingsSnapshot({
    String season = '2025',
  }) async {
    final response = await _getJsonWithCache(
      uri: Uri.parse('$_baseUrl$season/driverstandings/'),
      cacheKey: _cacheKey(bucket: 'driver_standings', season: season),
      failureMessage: 'Failed to load standings',
    );
    return CachedApiResponse(
      data: _parseDriverStandings(response.data),
      lastUpdated: response.lastUpdated,
      isFromCache: response.isFromCache,
    );
  }

  Future<List<ConstructorStanding>> getConstructorStandings({
    String season = '2025',
  }) async {
    final snapshot = await getConstructorStandingsSnapshot(season: season);
    return snapshot.data;
  }

  Future<CachedApiResponse<List<ConstructorStanding>>>
  getConstructorStandingsSnapshot({String season = '2025'}) async {
    final response = await _getJsonWithCache(
      uri: Uri.parse('$_baseUrl$season/constructorstandings/'),
      cacheKey: _cacheKey(bucket: 'constructor_standings', season: season),
      failureMessage: 'Failed to load team standings',
    );
    return CachedApiResponse(
      data: _parseConstructorStandings(response.data),
      lastUpdated: response.lastUpdated,
      isFromCache: response.isFromCache,
    );
  }

  Future<Race?> getNextRace({String season = '2025'}) async {
    final snapshot = await getNextRaceSnapshot(season: season);
    return snapshot.data;
  }

  Future<CachedApiResponse<Race?>> getNextRaceSnapshot({
    String season = '2025',
  }) async {
    final response = await _getJsonWithCache(
      uri: Uri.parse('$_baseUrl$season/next/'),
      cacheKey: _cacheKey(bucket: 'next_race', season: season),
      failureMessage: 'Failed to load next race',
    );
    return CachedApiResponse(
      data: _parseNextRace(response.data),
      lastUpdated: response.lastUpdated,
      isFromCache: response.isFromCache,
    );
  }

  Future<List<Race>> getRaceSchedule({String season = '2025'}) async {
    final snapshot = await getRaceScheduleSnapshot(season: season);
    return snapshot.data;
  }

  Future<CachedApiResponse<List<Race>>> getRaceScheduleSnapshot({
    String season = '2025',
  }) async {
    final response = await _getJsonWithCache(
      uri: Uri.parse('$_baseUrl$season/'),
      cacheKey: _cacheKey(bucket: 'race_schedule', season: season),
      failureMessage: 'Failed to load race schedule',
    );
    return CachedApiResponse(
      data: _parseRaceSchedule(response.data),
      lastUpdated: response.lastUpdated,
      isFromCache: response.isFromCache,
    );
  }

  Future<SeasonOverview> getSeasonOverview({String season = '2025'}) async {
    final responses = await Future.wait<Object>([
      getDriverStandingsSnapshot(season: season),
      getConstructorStandingsSnapshot(season: season),
      getNextRaceSnapshot(season: season),
      getRaceScheduleSnapshot(season: season),
    ]);

    final driverResponse =
        responses[0] as CachedApiResponse<List<DriverStanding>>;
    final constructorResponse =
        responses[1] as CachedApiResponse<List<ConstructorStanding>>;
    final nextRaceResponse = responses[2] as CachedApiResponse<Race?>;
    final scheduleResponse = responses[3] as CachedApiResponse<List<Race>>;

    final overviewLastUpdated = _oldestTimestamp([
      driverResponse.lastUpdated,
      constructorResponse.lastUpdated,
      scheduleResponse.lastUpdated,
    ]);

    return SeasonOverview(
      driverStandings: driverResponse.data,
      constructorStandings: constructorResponse.data,
      nextRace: nextRaceResponse.data,
      raceSchedule: scheduleResponse.data,
      driverStandingsUpdatedAt: driverResponse.lastUpdated,
      constructorStandingsUpdatedAt: constructorResponse.lastUpdated,
      raceScheduleUpdatedAt: scheduleResponse.lastUpdated,
      driverStandingsFromCache: driverResponse.isFromCache,
      constructorStandingsFromCache: constructorResponse.isFromCache,
      raceScheduleFromCache: scheduleResponse.isFromCache,
      lastUpdated: overviewLastUpdated,
      isFromCache:
          driverResponse.isFromCache ||
          constructorResponse.isFromCache ||
          scheduleResponse.isFromCache ||
          nextRaceResponse.isFromCache,
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
      final data = _decodeJsonMap(response.body);
      final mrData = data['MRData'] as Map<String, dynamic>? ?? {};
      final raceTable = mrData['RaceTable'] as Map<String, dynamic>? ?? {};
      final racesJson = raceTable['Races'] as List? ?? [];
      return racesJson
          .map(
            (json) =>
                DriverRaceResult.fromRaceJson(json as Map<String, dynamic>),
          )
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
      final data = _decodeJsonMap(response.body);
      final mrData = data['MRData'] as Map<String, dynamic>? ?? {};
      final raceTable = mrData['RaceTable'] as Map<String, dynamic>? ?? {};
      final racesJson = raceTable['Races'] as List? ?? [];
      return racesJson
          .map(
            (json) => TeamRaceResult.fromRaceJson(json as Map<String, dynamic>),
          )
          .toList();
    } else {
      throw Exception('Failed to load constructor results');
    }
  }

  Future<List<DriverSprintResult>> getDriverSprintResults({
    required String season,
    required String driverId,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$season/drivers/$driverId/sprint/'),
    );

    if (response.statusCode == 200) {
      final data = _decodeJsonMap(response.body);
      final mrData = data['MRData'] as Map<String, dynamic>? ?? {};
      final raceTable = mrData['RaceTable'] as Map<String, dynamic>? ?? {};
      final racesJson = raceTable['Races'] as List? ?? [];
      return racesJson
          .map(
            (json) =>
                DriverSprintResult.fromRaceJson(json as Map<String, dynamic>),
          )
          .toList();
    } else {
      throw Exception('Failed to load driver sprint results');
    }
  }

  Future<List<TeamSprintResult>> getConstructorSprintResults({
    required String season,
    required String constructorId,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$season/constructors/$constructorId/sprint/'),
    );

    if (response.statusCode == 200) {
      final data = _decodeJsonMap(response.body);
      final mrData = data['MRData'] as Map<String, dynamic>? ?? {};
      final raceTable = mrData['RaceTable'] as Map<String, dynamic>? ?? {};
      final racesJson = raceTable['Races'] as List? ?? [];
      return racesJson
          .map(
            (json) =>
                TeamSprintResult.fromRaceJson(json as Map<String, dynamic>),
          )
          .toList();
    } else {
      throw Exception('Failed to load constructor sprint results');
    }
  }

  Future<List<DriverQualifyingResult>> getDriverQualifyingResults({
    required String season,
    required String driverId,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$season/drivers/$driverId/qualifying/'),
    );

    if (response.statusCode == 200) {
      final data = _decodeJsonMap(response.body);
      final mrData = data['MRData'] as Map<String, dynamic>? ?? {};
      final raceTable = mrData['RaceTable'] as Map<String, dynamic>? ?? {};
      final racesJson = raceTable['Races'] as List? ?? [];
      return racesJson
          .map(
            (json) => DriverQualifyingResult.fromRaceJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    } else {
      throw Exception('Failed to load driver qualifying results');
    }
  }

  Future<List<TeamQualifyingResult>> getConstructorQualifyingResults({
    required String season,
    required String constructorId,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$season/constructors/$constructorId/qualifying/'),
    );

    if (response.statusCode == 200) {
      final data = _decodeJsonMap(response.body);
      final mrData = data['MRData'] as Map<String, dynamic>? ?? {};
      final raceTable = mrData['RaceTable'] as Map<String, dynamic>? ?? {};
      final racesJson = raceTable['Races'] as List? ?? [];
      return racesJson
          .map(
            (json) =>
                TeamQualifyingResult.fromRaceJson(json as Map<String, dynamic>),
          )
          .toList();
    } else {
      throw Exception('Failed to load constructor qualifying results');
    }
  }

  Future<SessionResults?> getLastRaceResults({required String season}) async {
    return _getSessionResults(
      season: season,
      endpoint: 'last/results/',
      cacheBucket: 'last_results_race',
      resultsKey: 'Results',
      type: SessionType.race,
    );
  }

  Future<SessionResults?> getLastQualifyingResults({
    required String season,
  }) async {
    return _getSessionResults(
      season: season,
      endpoint: 'last/qualifying/',
      cacheBucket: 'last_results_qualifying',
      resultsKey: 'QualifyingResults',
      type: SessionType.qualifying,
    );
  }

  Future<SessionResults?> getLastSprintResults({required String season}) async {
    return _getSessionResults(
      season: season,
      endpoint: 'last/sprint/',
      cacheBucket: 'last_results_sprint',
      resultsKey: 'SprintResults',
      type: SessionType.sprint,
    );
  }

  Future<SessionResults?> _getSessionResults({
    required String season,
    required String endpoint,
    required String cacheBucket,
    required String resultsKey,
    required SessionType type,
  }) async {
    final response = await _getJsonWithCache(
      uri: Uri.parse('$_baseUrl$season/$endpoint'),
      cacheKey: _cacheKey(bucket: cacheBucket, season: season),
      acceptedStatusCodes: const {200, 404},
      failureMessage: 'Failed to load session results',
    );
    return _parseSessionResults(
      response.data,
      resultsKey: resultsKey,
      type: type,
      lastUpdated: response.lastUpdated,
      isFromCache: response.isFromCache,
    );
  }

  Future<CachedApiResponse<Map<String, dynamic>>> _getJsonWithCache({
    required Uri uri,
    required String cacheKey,
    required String failureMessage,
    Set<int> acceptedStatusCodes = const {200},
  }) async {
    try {
      final response = await http.get(uri);
      if (!acceptedStatusCodes.contains(response.statusCode)) {
        throw Exception('$failureMessage (${response.statusCode})');
      }

      final data = _decodeJsonMap(response.body);
      final updatedAt = DateTime.now();
      await _writeCachedBody(cacheKey, response.body, updatedAt);
      return CachedApiResponse(
        data: data,
        lastUpdated: updatedAt,
        isFromCache: false,
      );
    } catch (_) {
      final cached = await _readCachedBody(cacheKey);
      if (cached != null) {
        final cachedData = _decodeJsonMap(cached.body);
        return CachedApiResponse(
          data: cachedData,
          lastUpdated: cached.updatedAt,
          isFromCache: true,
        );
      }
      throw Exception(failureMessage);
    }
  }

  static List<DriverStanding> _parseDriverStandings(Map<String, dynamic> data) {
    final mrData = data['MRData'] as Map<String, dynamic>? ?? {};
    final standingsTable =
        mrData['StandingsTable'] as Map<String, dynamic>? ?? {};
    final standingsLists = standingsTable['StandingsLists'] as List? ?? [];
    if (standingsLists.isEmpty) {
      return [];
    }
    final standingsJson =
        standingsLists.first['DriverStandings'] as List? ?? [];
    return standingsJson
        .map((json) => DriverStanding.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static List<ConstructorStanding> _parseConstructorStandings(
    Map<String, dynamic> data,
  ) {
    final mrData = data['MRData'] as Map<String, dynamic>? ?? {};
    final standingsTable =
        mrData['StandingsTable'] as Map<String, dynamic>? ?? {};
    final standingsLists = standingsTable['StandingsLists'] as List? ?? [];
    if (standingsLists.isEmpty) {
      return [];
    }
    final standingsJson =
        standingsLists.first['ConstructorStandings'] as List? ?? [];
    return standingsJson
        .map(
          (json) => ConstructorStanding.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  static Race? _parseNextRace(Map<String, dynamic> data) {
    final mrData = data['MRData'] as Map<String, dynamic>? ?? {};
    final raceTable = mrData['RaceTable'] as Map<String, dynamic>? ?? {};
    final racesJson = raceTable['Races'] as List? ?? [];
    if (racesJson.isEmpty) {
      return null;
    }
    return Race.fromJson(racesJson.first as Map<String, dynamic>);
  }

  static List<Race> _parseRaceSchedule(Map<String, dynamic> data) {
    final mrData = data['MRData'] as Map<String, dynamic>? ?? {};
    final raceTable = mrData['RaceTable'] as Map<String, dynamic>? ?? {};
    final racesJson = raceTable['Races'] as List? ?? [];
    return racesJson
        .map((json) => Race.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static SessionResults? _parseSessionResults(
    Map<String, dynamic> data, {
    required String resultsKey,
    required SessionType type,
    required DateTime? lastUpdated,
    required bool isFromCache,
  }) {
    final mrData = data['MRData'] as Map<String, dynamic>? ?? {};
    final raceTable = mrData['RaceTable'] as Map<String, dynamic>? ?? {};
    final racesJson = raceTable['Races'] as List? ?? [];
    if (racesJson.isEmpty) {
      return null;
    }
    final raceJson = racesJson.first as Map<String, dynamic>;
    final resultsJson = raceJson[resultsKey] as List? ?? [];
    final results = resultsJson
        .map(
          (json) =>
              ResultEntry.fromJson(json as Map<String, dynamic>, type: type),
        )
        .toList();
    return SessionResults(
      race: Race.fromJson(raceJson),
      results: results,
      type: type,
      lastUpdated: lastUpdated,
      isFromCache: isFromCache,
    );
  }

  static DateTime? _oldestTimestamp(List<DateTime?> timestamps) {
    final values = timestamps.whereType<DateTime>().toList();
    if (values.isEmpty) {
      return null;
    }
    values.sort((a, b) => a.compareTo(b));
    return values.first;
  }

  static String _cacheKey({required String bucket, required String season}) {
    return '$_cacheNamespace|$bucket|$season';
  }

  static String _cacheBodyKey(String key) => '$key|body';
  static String _cacheUpdatedAtKey(String key) => '$key|updated_at';

  Future<void> _writeCachedBody(
    String key,
    String body,
    DateTime updatedAt,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheBodyKey(key), body);
    await prefs.setInt(
      _cacheUpdatedAtKey(key),
      updatedAt.millisecondsSinceEpoch,
    );
  }

  Future<_CachedBody?> _readCachedBody(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final body = prefs.getString(_cacheBodyKey(key));
    if (body == null || body.isEmpty) {
      return null;
    }
    final updatedAtEpoch = prefs.getInt(_cacheUpdatedAtKey(key));
    final updatedAt = updatedAtEpoch == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(updatedAtEpoch);
    return _CachedBody(body: body, updatedAt: updatedAt);
  }

  static Map<String, dynamic> _decodeJsonMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    throw const FormatException('Unexpected response body');
  }
}
