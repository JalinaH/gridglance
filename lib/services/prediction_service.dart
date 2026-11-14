import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_service.dart';
import '../models/driver_standing.dart';

class PredictionSeasonScore {
  final int totalPoints;
  final int gradedPredictions;
  final int pendingPredictions;

  const PredictionSeasonScore({
    required this.totalPoints,
    required this.gradedPredictions,
    required this.pendingPredictions,
  });

  int get totalPredictions => gradedPredictions + pendingPredictions;
}

class PredictionService {
  static const String _namespace = 'prediction_v1';
  static const String _racePodiumCategory = 'race_podium';
  static const String _qualifyingTop3Category = 'qualifying_top3';

  /// Stored actual top 3 per session, so grading does not hit the API for
  /// every saved prediction each time a race screen opens.
  static const String _resultNamespace = 'prediction_result_v1';

  /// A classification can still change for a while after the flag (penalties,
  /// disqualifications). Until it has been stored this long it is re-checked,
  /// at most once per [_resultRecheckInterval]; after that it is final.
  static const Duration _resultSettleTime = Duration(days: 3);
  static const Duration _resultRecheckInterval = Duration(hours: 6);

  /// How long a session with no result yet (not run, or still being
  /// classified) is left alone before asking again.
  static const Duration _missRetryInterval = Duration(minutes: 10);
  static final Map<String, DateTime> _recentMisses = {};

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  @visibleForTesting
  static void resetForTesting() {
    _recentMisses.clear();
    clock = DateTime.now;
  }

  /// Drivers offered in the prediction picker for [season].
  ///
  /// Standings are empty until the first race of a season is scored, which
  /// used to make round 1 impossible to predict. In that case the previous
  /// season's standings stand in, so rookies new to the grid are missing
  /// until round 1 is done.
  Future<List<DriverStanding>> getPredictionDrivers({
    required String season,
    ApiService? apiService,
    Future<List<DriverStanding>> Function(String season)? standingsFetcher,
  }) async {
    final api = apiService ?? ApiService();
    final fetch = standingsFetcher ?? (s) => api.getDriverStandings(season: s);

    Future<List<DriverStanding>> safe(String s) async {
      try {
        return await fetch(s);
      } catch (_) {
        return const [];
      }
    }

    final current = await safe(season);
    if (current.length >= 3) return current;
    final year = int.tryParse(season);
    if (year == null) return current;
    final previous = await safe('${year - 1}');
    return previous.length >= 3 ? previous : current;
  }

  Future<List<String>> getRacePodiumPrediction({
    required String season,
    required String round,
  }) {
    return _getTop3Prediction(
      season: season,
      round: round,
      category: _racePodiumCategory,
    );
  }

  Future<void> setRacePodiumPrediction({
    required String season,
    required String round,
    required List<String> driverIds,
  }) {
    return _setTop3Prediction(
      season: season,
      round: round,
      category: _racePodiumCategory,
      driverIds: driverIds,
    );
  }

  Future<List<String>> getQualifyingTop3Prediction({
    required String season,
    required String round,
  }) {
    return _getTop3Prediction(
      season: season,
      round: round,
      category: _qualifyingTop3Category,
    );
  }

  Future<void> setQualifyingTop3Prediction({
    required String season,
    required String round,
    required List<String> driverIds,
  }) {
    return _setTop3Prediction(
      season: season,
      round: round,
      category: _qualifyingTop3Category,
      driverIds: driverIds,
    );
  }

  Future<PredictionSeasonScore> getSeasonScore({
    required String season,
    ApiService? apiService,
    Future<List<String>> Function(String round)? raceTop3Fetcher,
    Future<List<String>> Function(String round)? qualifyingTop3Fetcher,
  }) async {
    final api = apiService ?? ApiService();
    final raceFetcher =
        raceTop3Fetcher ??
        (round) => api.getRaceTop3DriverIds(season: season, round: round);
    final qualifyingFetcher =
        qualifyingTop3Fetcher ??
        (round) => api.getQualifyingTop3DriverIds(season: season, round: round);

    final entries = await _loadPredictionEntries(season: season);
    if (entries.isEmpty) {
      return const PredictionSeasonScore(
        totalPoints: 0,
        gradedPredictions: 0,
        pendingPredictions: 0,
      );
    }

    var totalPoints = 0;
    var gradedPredictions = 0;
    var pendingPredictions = 0;

    final futures = entries.map((entry) async {
      if (entry.driverIds.length < 3) {
        return const _PredictionScoreOutcome(isGraded: false, points: 0);
      }
      try {
        final actualTop3 = await _actualTop3(
          season: season,
          round: entry.round,
          category: entry.category,
          fetch: switch (entry.category) {
            _racePodiumCategory => raceFetcher,
            _qualifyingTop3Category => qualifyingFetcher,
            _ => (_) async => const <String>[],
          },
        );
        if (actualTop3.length < 3) {
          return const _PredictionScoreOutcome(isGraded: false, points: 0);
        }
        final score = scoreTop3Prediction(
          predictedIds: entry.driverIds,
          actualIds: actualTop3,
        );
        return _PredictionScoreOutcome(isGraded: true, points: score);
      } catch (_) {
        return const _PredictionScoreOutcome(isGraded: false, points: 0);
      }
    });

    final outcomes = await Future.wait(futures);
    for (final outcome in outcomes) {
      if (outcome.isGraded) {
        gradedPredictions += 1;
        totalPoints += outcome.points;
      } else {
        pendingPredictions += 1;
      }
    }

    return PredictionSeasonScore(
      totalPoints: totalPoints,
      gradedPredictions: gradedPredictions,
      pendingPredictions: pendingPredictions,
    );
  }

  /// The real top 3 for a session, from local storage when possible.
  ///
  /// Returns fewer than 3 ids when the session has no result yet. Throws only
  /// when the fetch fails and nothing is stored.
  Future<List<String>> _actualTop3({
    required String season,
    required String round,
    required String category,
    required Future<List<String>> Function(String round) fetch,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_resultNamespace|$season|$round|$category';
    final now = clock();

    // Stored as [firstSeenMs, lastFetchedMs, id1, id2, id3].
    final stored = prefs.getStringList(key);
    List<String>? cachedIds;
    DateTime? firstSeen;
    if (stored != null && stored.length == 5) {
      final firstSeenMs = int.tryParse(stored[0]);
      final lastFetchedMs = int.tryParse(stored[1]);
      if (firstSeenMs != null && lastFetchedMs != null) {
        cachedIds = stored.sublist(2);
        firstSeen = DateTime.fromMillisecondsSinceEpoch(firstSeenMs);
        final lastFetched = DateTime.fromMillisecondsSinceEpoch(lastFetchedMs);
        final settled = now.difference(firstSeen) >= _resultSettleTime;
        final checkedRecently =
            now.difference(lastFetched) < _resultRecheckInterval;
        if (settled || checkedRecently) return cachedIds;
      }
    }

    if (cachedIds == null) {
      final missedAt = _recentMisses[key];
      if (missedAt != null && now.difference(missedAt) < _missRetryInterval) {
        return const [];
      }
    }

    final List<String> fetched;
    try {
      fetched = await fetch(round);
    } catch (_) {
      if (cachedIds != null) return cachedIds;
      rethrow;
    }

    if (fetched.length < 3) {
      if (cachedIds != null) return cachedIds;
      _recentMisses[key] = now;
      return fetched;
    }
    _recentMisses.remove(key);
    final top3 = fetched.take(3).toList();
    await prefs.setStringList(key, [
      '${(firstSeen ?? now).millisecondsSinceEpoch}',
      '${now.millisecondsSinceEpoch}',
      ...top3,
    ]);
    return top3;
  }

  static int scoreTop3Prediction({
    required List<String> predictedIds,
    required List<String> actualIds,
  }) {
    final predicted = _normalizeTop3(predictedIds);
    final actual = _normalizeTop3(actualIds);
    if (predicted.isEmpty || actual.isEmpty) {
      return 0;
    }

    var points = 0;
    final maxLength = predicted.length < actual.length
        ? predicted.length
        : actual.length;
    for (var index = 0; index < maxLength; index += 1) {
      final driverId = predicted[index];
      if (driverId == actual[index]) {
        points += 3;
      } else if (actual.contains(driverId)) {
        points += 1;
      }
    }
    return points;
  }

  Future<List<String>> _getTop3Prediction({
    required String season,
    required String round,
    required String category,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getStringList(
      _predictionKey(season: season, round: round, category: category),
    );
    return _normalizeTop3(value ?? const []);
  }

  Future<void> _setTop3Prediction({
    required String season,
    required String round,
    required String category,
    required List<String> driverIds,
  }) async {
    final normalized = _normalizeTop3(driverIds);
    if (normalized.length != 3) {
      throw ArgumentError('Top 3 prediction must include exactly 3 drivers.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _predictionKey(season: season, round: round, category: category),
      normalized,
    );
  }

  Future<List<_StoredPredictionEntry>> _loadPredictionEntries({
    required String season,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = <_StoredPredictionEntry>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('$_namespace|$season|')) {
        continue;
      }
      final parts = key.split('|');
      if (parts.length != 4) {
        continue;
      }
      final category = parts[3];
      if (category != _racePodiumCategory &&
          category != _qualifyingTop3Category) {
        continue;
      }
      final round = parts[2];
      final driverIds = _normalizeTop3(prefs.getStringList(key) ?? const []);
      if (driverIds.isEmpty) {
        continue;
      }
      entries.add(
        _StoredPredictionEntry(
          round: round,
          category: category,
          driverIds: driverIds,
        ),
      );
    }
    entries.sort((a, b) {
      final roundA = int.tryParse(a.round);
      final roundB = int.tryParse(b.round);
      if (roundA != null && roundB != null) {
        return roundA.compareTo(roundB);
      }
      return a.round.compareTo(b.round);
    });
    return entries;
  }

  static List<String> _normalizeTop3(List<String> input) {
    final normalized = <String>[];
    for (final value in input) {
      final id = value.trim();
      if (id.isEmpty || normalized.contains(id)) {
        continue;
      }
      normalized.add(id);
      if (normalized.length == 3) {
        break;
      }
    }
    return normalized;
  }

  static String _predictionKey({
    required String season,
    required String round,
    required String category,
  }) {
    return '$_namespace|$season|$round|$category';
  }
}

class _StoredPredictionEntry {
  final String round;
  final String category;
  final List<String> driverIds;

  const _StoredPredictionEntry({
    required this.round,
    required this.category,
    required this.driverIds,
  });
}

class _PredictionScoreOutcome {
  final bool isGraded;
  final int points;

  const _PredictionScoreOutcome({required this.isGraded, required this.points});
}
