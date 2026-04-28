import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/constructor_standing.dart';
import '../models/driver_standing.dart';
import '../models/race.dart';
import '../models/race_result.dart';
import '../models/session_results.dart';
import '../models/season_overview.dart';
import '../utils/json_safe.dart';

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

class _ApiHttpException implements Exception {
  final int statusCode;
  const _ApiHttpException(this.statusCode);

  @override
  String toString() => '_ApiHttpException(statusCode: $statusCode)';
}

class ApiService {
  static const String _baseUrl = 'https://api.jolpi.ca/ergast/f1/';
  static const String _cacheNamespace = 'api_cache_v1';

  static final Map<String, Future<CachedApiResponse<dynamic>>> _inFlight = {};
  static final Random _retryJitter = Random();
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const int _maxRetries = 2;
  static const Duration _retryBaseDelay = Duration(milliseconds: 250);

  Future<List<DriverStanding>> getDriverStandings({String? season}) async {
    season ??= DateTime.now().year.toString();
    final snapshot = await getDriverStandingsSnapshot(season: season);
    return snapshot.data;
  }

  Future<CachedApiResponse<List<DriverStanding>>> getDriverStandingsSnapshot({
    String? season,
  }) async {
    season ??= DateTime.now().year.toString();
    return _getJsonWithCache<List<DriverStanding>>(
      uri: Uri.parse('$_baseUrl$season/driverstandings/'),
      cacheKey: _cacheKey(bucket: 'driver_standings', season: season),
      failureMessage: 'Failed to load standings',
      parse: _parseDriverStandings,
    );
  }

  Future<List<ConstructorStanding>> getConstructorStandings({
    String? season,
  }) async {
    season ??= DateTime.now().year.toString();
    final snapshot = await getConstructorStandingsSnapshot(season: season);
    return snapshot.data;
  }

  Future<CachedApiResponse<List<ConstructorStanding>>>
  getConstructorStandingsSnapshot({String? season}) async {
    season ??= DateTime.now().year.toString();
    return _getJsonWithCache<List<ConstructorStanding>>(
      uri: Uri.parse('$_baseUrl$season/constructorstandings/'),
      cacheKey: _cacheKey(bucket: 'constructor_standings', season: season),
      failureMessage: 'Failed to load team standings',
      parse: _parseConstructorStandings,
    );
  }

  Future<Race?> getNextRace({String? season}) async {
    season ??= DateTime.now().year.toString();
    final snapshot = await getNextRaceSnapshot(season: season);
    return snapshot.data;
  }

  Future<CachedApiResponse<Race?>> getNextRaceSnapshot({String? season}) async {
    season ??= DateTime.now().year.toString();
    return _getJsonWithCache<Race?>(
      uri: Uri.parse('$_baseUrl$season/next/'),
      cacheKey: _cacheKey(bucket: 'next_race', season: season),
      failureMessage: 'Failed to load next race',
      parse: _parseNextRace,
    );
  }

  Future<List<Race>> getRaceSchedule({String? season}) async {
    season ??= DateTime.now().year.toString();
    final snapshot = await getRaceScheduleSnapshot(season: season);
    return snapshot.data;
  }

  Future<CachedApiResponse<List<Race>>> getRaceScheduleSnapshot({
    String? season,
  }) async {
    season ??= DateTime.now().year.toString();
    return _getJsonWithCache<List<Race>>(
      uri: Uri.parse('$_baseUrl$season/'),
      cacheKey: _cacheKey(bucket: 'race_schedule', season: season),
      failureMessage: 'Failed to load race schedule',
      parse: _parseRaceSchedule,
    );
  }

  Future<SeasonOverview> getSeasonOverview({String? season}) async {
    season ??= DateTime.now().year.toString();
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
      final racesJson = _extractRaces(data);
      return racesJson
          .map((json) => JsonSafe.asMapOrNull(json))
          .whereType<Map<String, dynamic>>()
          .map(DriverRaceResult.fromRaceJson)
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
      final racesJson = _extractRaces(data);
      return racesJson
          .map((json) => JsonSafe.asMapOrNull(json))
          .whereType<Map<String, dynamic>>()
          .map(TeamRaceResult.fromRaceJson)
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
      final racesJson = _extractRaces(data);
      return racesJson
          .map((json) => JsonSafe.asMapOrNull(json))
          .whereType<Map<String, dynamic>>()
          .map(DriverSprintResult.fromRaceJson)
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
      final racesJson = _extractRaces(data);
      return racesJson
          .map((json) => JsonSafe.asMapOrNull(json))
          .whereType<Map<String, dynamic>>()
          .map(TeamSprintResult.fromRaceJson)
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
      final racesJson = _extractRaces(data);
      return racesJson
          .map((json) => JsonSafe.asMapOrNull(json))
          .whereType<Map<String, dynamic>>()
          .map(DriverQualifyingResult.fromRaceJson)
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
      final racesJson = _extractRaces(data);
      return racesJson
          .map((json) => JsonSafe.asMapOrNull(json))
          .whereType<Map<String, dynamic>>()
          .map(TeamQualifyingResult.fromRaceJson)
          .toList();
    } else {
      throw Exception('Failed to load constructor qualifying results');
    }
  }

  Future<List<String>> getRaceTop3DriverIds({
    required String season,
    required String round,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$season/$round/results/'),
    );
    if (response.statusCode == 404) {
      return [];
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to load race results');
    }
    final data = _decodeJsonMap(response.body);
    final racesJson = _extractRaces(data);
    if (racesJson.isEmpty) {
      return [];
    }
    final raceJson = JsonSafe.asMapOrNull(racesJson.first);
    if (raceJson == null) {
      return [];
    }
    final results = JsonSafe.asList(raceJson['Results']);
    return results
        .take(3)
        .map((result) {
          final resultJson = JsonSafe.asMap(result);
          final driver = JsonSafe.asMap(resultJson['Driver']);
          return '${driver['driverId'] ?? ''}';
        })
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<List<String>> getQualifyingTop3DriverIds({
    required String season,
    required String round,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$season/$round/qualifying/'),
    );
    if (response.statusCode == 404) {
      return [];
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to load qualifying results');
    }
    final data = _decodeJsonMap(response.body);
    final racesJson = _extractRaces(data);
    if (racesJson.isEmpty) {
      return [];
    }
    final raceJson = JsonSafe.asMapOrNull(racesJson.first);
    if (raceJson == null) {
      return [];
    }
    final results = JsonSafe.asList(raceJson['QualifyingResults']);
    return results
        .take(3)
        .map((result) {
          final resultJson = JsonSafe.asMap(result);
          final driver = JsonSafe.asMap(resultJson['Driver']);
          return '${driver['driverId'] ?? ''}';
        })
        .where((id) => id.isNotEmpty)
        .toList();
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
    final response = await _getJsonWithCache<SessionResults?>(
      uri: Uri.parse('$_baseUrl$season/$endpoint'),
      cacheKey: _cacheKey(bucket: cacheBucket, season: season),
      acceptedStatusCodes: const {200, 404},
      failureMessage: 'Failed to load session results',
      parse: (data) =>
          _parseSessionResults(data, resultsKey: resultsKey, type: type),
    );
    final parsed = response.data;
    if (parsed == null) {
      return null;
    }
    return SessionResults(
      race: parsed.race,
      results: parsed.results,
      type: parsed.type,
      lastUpdated: response.lastUpdated,
      isFromCache: response.isFromCache,
    );
  }

  Future<CachedApiResponse<T>> _getJsonWithCache<T>({
    required Uri uri,
    required String cacheKey,
    required String failureMessage,
    required T Function(Map<String, dynamic>) parse,
    Set<int> acceptedStatusCodes = const {200},
  }) async {
    final dedupeKey = uri.toString();
    final existing = _inFlight[dedupeKey];
    if (existing != null) {
      return (await existing) as CachedApiResponse<T>;
    }
    final future = _fetchAndParse<T>(
      uri: uri,
      cacheKey: cacheKey,
      failureMessage: failureMessage,
      parse: parse,
      acceptedStatusCodes: acceptedStatusCodes,
    );
    _inFlight[dedupeKey] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(dedupeKey);
    }
  }

  Future<CachedApiResponse<T>> _fetchAndParse<T>({
    required Uri uri,
    required String cacheKey,
    required String failureMessage,
    required T Function(Map<String, dynamic>) parse,
    required Set<int> acceptedStatusCodes,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http.get(uri).timeout(_requestTimeout);
        if (!acceptedStatusCodes.contains(response.statusCode)) {
          throw _ApiHttpException(response.statusCode);
        }
        final data = _decodeJsonMap(response.body);
        final parsed = parse(data);
        final updatedAt = DateTime.now();
        await _writeCachedBody(cacheKey, response.body, updatedAt);
        return CachedApiResponse(
          data: parsed,
          lastUpdated: updatedAt,
          isFromCache: false,
        );
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt < _maxRetries && _isTransient(error)) {
          final delay = _retryDelay(attempt);
          if (kDebugMode) {
            debugPrint(
              'ApiService retry ${attempt + 1}/$_maxRetries '
              'after ${delay.inMilliseconds}ms for ${uri.path}: $error',
            );
          }
          await Future.delayed(delay);
          continue;
        }
        break;
      }
    }
    if (lastError != null) {
      _logApiError(uri, lastError, lastStackTrace ?? StackTrace.empty);
    }
    final cached = await _readCachedBody(cacheKey);
    if (cached != null) {
      try {
        final cachedData = _decodeJsonMap(cached.body);
        return CachedApiResponse(
          data: parse(cachedData),
          lastUpdated: cached.updatedAt,
          isFromCache: true,
        );
      } catch (cacheError, cacheStack) {
        _logApiError(uri, cacheError, cacheStack, fromCache: true);
      }
    }
    throw Exception(failureMessage);
  }

  static bool _isTransient(Object error) {
    if (error is _ApiHttpException) return error.statusCode >= 500;
    return error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException;
  }

  static Duration _retryDelay(int attempt) {
    final baseMs = _retryBaseDelay.inMilliseconds * (1 << attempt);
    final jitterMs = baseMs * (_retryJitter.nextDouble() * 0.5 - 0.25);
    final totalMs = (baseMs + jitterMs).round();
    return Duration(milliseconds: totalMs < 0 ? 0 : totalMs);
  }

  static void _logApiError(
    Uri uri,
    Object error,
    StackTrace stackTrace, {
    bool fromCache = false,
  }) {
    if (!kDebugMode) return;
    final source = fromCache ? 'cache' : 'network';
    final classification = _classifyError(error);
    debugPrint('ApiService [$source/$classification] ${uri.path}: $error');
  }

  static String _classifyError(Object error) {
    if (error is _ApiHttpException) {
      final code = error.statusCode;
      if (code >= 500) return 'http-5xx';
      if (code >= 400) return 'http-4xx';
      return 'http-$code';
    }
    if (error is SocketException) return 'network';
    if (error is TimeoutException) return 'timeout';
    if (error is http.ClientException) return 'http-client';
    if (error is FormatException) return 'parse';
    return 'unknown';
  }

  static List<dynamic> _extractRaces(Map<String, dynamic> data) {
    final mrData = JsonSafe.asMap(data['MRData']);
    final raceTable = JsonSafe.asMap(mrData['RaceTable']);
    return JsonSafe.asList(raceTable['Races']);
  }

  static List<DriverStanding> _parseDriverStandings(Map<String, dynamic> data) {
    final mrData = JsonSafe.asMap(data['MRData']);
    final standingsTable = JsonSafe.asMap(mrData['StandingsTable']);
    final standingsLists = JsonSafe.asList(standingsTable['StandingsLists']);
    if (standingsLists.isEmpty) {
      return [];
    }
    final firstList = JsonSafe.asMap(standingsLists.first);
    final standingsJson = JsonSafe.asList(firstList['DriverStandings']);
    return standingsJson
        .map((json) => JsonSafe.asMapOrNull(json))
        .whereType<Map<String, dynamic>>()
        .map(DriverStanding.fromJson)
        .toList();
  }

  static List<ConstructorStanding> _parseConstructorStandings(
    Map<String, dynamic> data,
  ) {
    final mrData = JsonSafe.asMap(data['MRData']);
    final standingsTable = JsonSafe.asMap(mrData['StandingsTable']);
    final standingsLists = JsonSafe.asList(standingsTable['StandingsLists']);
    if (standingsLists.isEmpty) {
      return [];
    }
    final firstList = JsonSafe.asMap(standingsLists.first);
    final standingsJson = JsonSafe.asList(firstList['ConstructorStandings']);
    return standingsJson
        .map((json) => JsonSafe.asMapOrNull(json))
        .whereType<Map<String, dynamic>>()
        .map(ConstructorStanding.fromJson)
        .toList();
  }

  static Race? _parseNextRace(Map<String, dynamic> data) {
    final mrData = JsonSafe.asMap(data['MRData']);
    final raceTable = JsonSafe.asMap(mrData['RaceTable']);
    final racesJson = JsonSafe.asList(raceTable['Races']);
    if (racesJson.isEmpty) {
      return null;
    }
    final firstRace = JsonSafe.asMapOrNull(racesJson.first);
    if (firstRace == null) {
      return null;
    }
    return Race.fromJson(firstRace);
  }

  static List<Race> _parseRaceSchedule(Map<String, dynamic> data) {
    final mrData = JsonSafe.asMap(data['MRData']);
    final raceTable = JsonSafe.asMap(mrData['RaceTable']);
    final racesJson = JsonSafe.asList(raceTable['Races']);
    return racesJson
        .map((json) => JsonSafe.asMapOrNull(json))
        .whereType<Map<String, dynamic>>()
        .map(Race.fromJson)
        .toList();
  }

  static SessionResults? _parseSessionResults(
    Map<String, dynamic> data, {
    required String resultsKey,
    required SessionType type,
  }) {
    final mrData = JsonSafe.asMap(data['MRData']);
    final raceTable = JsonSafe.asMap(mrData['RaceTable']);
    final racesJson = JsonSafe.asList(raceTable['Races']);
    if (racesJson.isEmpty) {
      return null;
    }
    final raceJson = JsonSafe.asMapOrNull(racesJson.first);
    if (raceJson == null) {
      return null;
    }
    final resultsJson = JsonSafe.asList(raceJson[resultsKey]);
    final results = resultsJson
        .map((json) => JsonSafe.asMapOrNull(json))
        .whereType<Map<String, dynamic>>()
        .map((json) => ResultEntry.fromJson(json, type: type))
        .toList();
    return SessionResults(
      race: Race.fromJson(raceJson),
      results: results,
      type: type,
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
