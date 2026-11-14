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
import '../services/crash_reporting.dart';
import '../utils/json_safe.dart';

Map<String, dynamic> _decodeJsonInIsolate(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.cast<String, dynamic>();
  }
  throw const FormatException('Unexpected response body');
}

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

/// Driver and constructor standings for display, with the season they
/// actually belong to.
class StandingsSnapshot {
  /// Season the caller asked for.
  final String requestedSeason;

  /// Season the standings are from.
  final String season;
  final CachedApiResponse<List<DriverStanding>> drivers;
  final CachedApiResponse<List<ConstructorStanding>> constructors;

  const StandingsSnapshot({
    required this.requestedSeason,
    required this.season,
    required this.drivers,
    required this.constructors,
  });

  /// True when these are last season's final standings standing in for a
  /// season that has not been scored yet.
  bool get isPreviousSeason => season != requestedSeason;
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

  /// Jolpica's maximum page size. Its default is 30 rows, which truncates
  /// anything longer unless we ask for more and follow `offset`.
  static const int _pageSize = 100;

  /// Upper bound on pages followed for one endpoint, so a malformed `total`
  /// can never loop forever. 10 pages is 1,000 rows; a season needs one.
  static const int _maxResultPages = 10;
  static const List<String> _resultRowKeys = [
    'Results',
    'QualifyingResults',
    'SprintResults',
  ];

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
      uri: Uri.parse('$_baseUrl$season/driverstandings/?limit=$_pageSize'),
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
      uri: Uri.parse('$_baseUrl$season/constructorstandings/?limit=$_pageSize'),
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

  /// Debug-only switch that makes every season behave as if it had no
  /// standings yet, so off-season mode can be seen without waiting for
  /// January. Ignored in release and profile builds.
  static bool debugForceOffSeason = false;

  static bool get _forceOffSeason => kDebugMode && debugForceOffSeason;

  /// Standings for [season], or the previous season's final standings when
  /// [season] has none yet.
  ///
  /// Between the new year and the first race the current season has a
  /// calendar but no standings. Rather than showing empty tables for weeks,
  /// callers get last season's final standings, flagged through
  /// [StandingsSnapshot.isPreviousSeason] so they can label them.
  Future<StandingsSnapshot> getStandingsOrPreviousSeason({
    String? season,
  }) async {
    final requested = season ?? DateTime.now().year.toString();

    Future<StandingsSnapshot> load(String forSeason) async {
      // Future.wait so that when both requests fail, neither error is left
      // unhandled.
      final results = await Future.wait<Object>([
        getDriverStandingsSnapshot(season: forSeason),
        getConstructorStandingsSnapshot(season: forSeason),
      ]);
      return StandingsSnapshot(
        requestedSeason: requested,
        season: forSeason,
        drivers: results[0] as CachedApiResponse<List<DriverStanding>>,
        constructors:
            results[1] as CachedApiResponse<List<ConstructorStanding>>,
      );
    }

    bool isEmpty(StandingsSnapshot snapshot) =>
        snapshot.drivers.data.isEmpty && snapshot.constructors.data.isEmpty;

    final current = await load(requested);
    if (!isEmpty(current) && !_forceOffSeason) return current;
    final year = int.tryParse(requested);
    if (year == null) return current;
    try {
      final previous = await load('${year - 1}');
      return isEmpty(previous) ? current : previous;
    } catch (_) {
      // The fallback is a nicety; an empty current season is still valid.
      return current;
    }
  }

  Future<SeasonOverview> getSeasonOverview({String? season}) async {
    season ??= DateTime.now().year.toString();
    final responses = await Future.wait<Object>([
      getStandingsOrPreviousSeason(season: season),
      getNextRaceSnapshot(season: season),
      getRaceScheduleSnapshot(season: season),
    ]);

    final standings = responses[0] as StandingsSnapshot;
    final driverResponse = standings.drivers;
    final constructorResponse = standings.constructors;
    final nextRaceResponse = responses[1] as CachedApiResponse<Race?>;
    final scheduleResponse = responses[2] as CachedApiResponse<List<Race>>;

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
      standingsSeason: standings.season,
      isOffSeason: standings.isPreviousSeason,
    );
  }

  Future<List<DriverRaceResult>> getDriverResults({
    required String season,
    required String driverId,
  }) {
    return _fetchRaceResultsByEndpoint(
      endpoint: '$season/drivers/$driverId/results/',
      failureMessage: 'Failed to load driver results',
      fromRaceJson: DriverRaceResult.fromRaceJson,
    );
  }

  Future<List<TeamRaceResult>> getConstructorResults({
    required String season,
    required String constructorId,
  }) {
    return _fetchRaceResultsByEndpoint(
      endpoint: '$season/constructors/$constructorId/results/',
      failureMessage: 'Failed to load constructor results',
      fromRaceJson: TeamRaceResult.fromRaceJson,
    );
  }

  Future<List<DriverSprintResult>> getDriverSprintResults({
    required String season,
    required String driverId,
  }) {
    return _fetchRaceResultsByEndpoint(
      endpoint: '$season/drivers/$driverId/sprint/',
      failureMessage: 'Failed to load driver sprint results',
      fromRaceJson: DriverSprintResult.fromRaceJson,
    );
  }

  Future<List<TeamSprintResult>> getConstructorSprintResults({
    required String season,
    required String constructorId,
  }) {
    return _fetchRaceResultsByEndpoint(
      endpoint: '$season/constructors/$constructorId/sprint/',
      failureMessage: 'Failed to load constructor sprint results',
      fromRaceJson: TeamSprintResult.fromRaceJson,
    );
  }

  Future<List<DriverQualifyingResult>> getDriverQualifyingResults({
    required String season,
    required String driverId,
  }) {
    return _fetchRaceResultsByEndpoint(
      endpoint: '$season/drivers/$driverId/qualifying/',
      failureMessage: 'Failed to load driver qualifying results',
      fromRaceJson: DriverQualifyingResult.fromRaceJson,
    );
  }

  Future<List<TeamQualifyingResult>> getConstructorQualifyingResults({
    required String season,
    required String constructorId,
  }) {
    return _fetchRaceResultsByEndpoint(
      endpoint: '$season/constructors/$constructorId/qualifying/',
      failureMessage: 'Failed to load constructor qualifying results',
      fromRaceJson: TeamQualifyingResult.fromRaceJson,
    );
  }

  Future<List<T>> _fetchRaceResultsByEndpoint<T>({
    required String endpoint,
    required String failureMessage,
    required T Function(Map<String, dynamic>) fromRaceJson,
  }) async {
    final races = await _fetchAllRaces(
      endpoint: endpoint,
      failureMessage: failureMessage,
    );
    return races.map(fromRaceJson).toList();
  }

  /// Fetches every page of a race-table endpoint and returns one entry per
  /// race.
  ///
  /// Jolpica pages by result row, not by race (30 rows by default), so a team
  /// with two cars runs past the first page mid-season. A race whose rows
  /// straddle a page boundary comes back once per page; those are merged so
  /// callers see each race once with all of its rows.
  Future<List<Map<String, dynamic>>> _fetchAllRaces({
    required String endpoint,
    required String failureMessage,
  }) async {
    final racesByKey = <String, Map<String, dynamic>>{};
    var offset = 0;
    for (var page = 0; page < _maxResultPages; page++) {
      final uri = Uri.parse(
        '$_baseUrl$endpoint',
      ).replace(queryParameters: {'limit': '$_pageSize', 'offset': '$offset'});
      final response = await _getWithRetry(uri);
      if (response.statusCode != 200) {
        throw Exception(failureMessage);
      }
      final data = await _decodeJsonMap(response.body);
      for (final raw in _extractRaces(data)) {
        final race = JsonSafe.asMapOrNull(raw);
        if (race == null) continue;
        final round = '${race['round'] ?? ''}';
        // Without a round there is nothing to match on, so never merge.
        final key = round.isEmpty
            ? 'unkeyed|${racesByKey.length}'
            : '${race['season'] ?? ''}|$round';
        final existing = racesByKey[key];
        if (existing == null) {
          racesByKey[key] = Map<String, dynamic>.of(race);
        } else {
          _mergeResultRows(into: existing, from: race);
        }
      }

      final mrData = JsonSafe.asMap(data['MRData']);
      final total = int.tryParse('${mrData['total'] ?? ''}');
      // Trust the page size the server actually applied; it may cap ours.
      final served = int.tryParse('${mrData['limit'] ?? ''}') ?? _pageSize;
      if (total == null || served <= 0) break;
      offset += served;
      if (offset >= total) break;
    }
    return racesByKey.values.toList();
  }

  static void _mergeResultRows({
    required Map<String, dynamic> into,
    required Map<String, dynamic> from,
  }) {
    for (final key in _resultRowKeys) {
      final extra = JsonSafe.asList(from[key]);
      if (extra.isEmpty) continue;
      into[key] = [...JsonSafe.asList(into[key]), ...extra];
    }
  }

  Future<List<String>> getRaceTop3DriverIds({
    required String season,
    required String round,
  }) async {
    final response = await _getWithRetry(
      Uri.parse('$_baseUrl$season/$round/results/'),
    );
    if (response.statusCode == 404) {
      return [];
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to load race results');
    }
    final data = await _decodeJsonMap(response.body);
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
    final response = await _getWithRetry(
      Uri.parse('$_baseUrl$season/$round/qualifying/'),
    );
    if (response.statusCode == 404) {
      return [];
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to load qualifying results');
    }
    final data = await _decodeJsonMap(response.body);
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
        final data = await _decodeJsonMap(response.body);
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
        final cachedData = await _decodeJsonMap(cached.body);
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

  /// GET with the same timeout and transient-failure retries as the cached
  /// endpoints, for calls that handle status codes themselves. 5xx responses
  /// are retried; the final response (any status) is returned to the caller.
  /// Throws the last error if every attempt failed at the network level.
  static Future<http.Response> _getWithRetry(Uri uri) async {
    for (var attempt = 0; ; attempt++) {
      final canRetry = attempt < _maxRetries;
      try {
        final response = await http.get(uri).timeout(_requestTimeout);
        if (response.statusCode >= 500 && canRetry) {
          await Future.delayed(_retryDelay(attempt));
          continue;
        }
        return response;
      } catch (error) {
        if (!canRetry || !_isTransient(error)) rethrow;
        if (kDebugMode) {
          debugPrint(
            'ApiService retry ${attempt + 1}/$_maxRetries for ${uri.path}: '
            '$error',
          );
        }
        await Future.delayed(_retryDelay(attempt));
      }
    }
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
    final source = fromCache ? 'cache' : 'network';
    final classification = _classifyError(error);
    if (kDebugMode) {
      debugPrint('ApiService [$source/$classification] ${uri.path}: $error');
    }
    // Only report failures that are likely a real bug or a backend
    // contract change. Network blips and 5xx are expected on flaky
    // connections and would just create Sentry noise.
    const reportableClassifications = {'parse', 'http-4xx', 'unknown'};
    if (!reportableClassifications.contains(classification)) return;
    unawaited(
      CrashReporting.captureException(
        error,
        stackTrace: stackTrace,
        hint: 'api_service.${uri.path}',
        tags: {'classification': classification, 'source': source},
      ),
    );
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

  static const int _isolateDecodeThreshold = 8 * 1024;

  static Future<Map<String, dynamic>> _decodeJsonMap(String body) async {
    if (body.length < _isolateDecodeThreshold) {
      return _decodeJsonInIsolate(body);
    }
    return compute(_decodeJsonInIsolate, body);
  }
}
