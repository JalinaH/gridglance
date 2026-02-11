import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_service.dart';

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
        final actualTop3 = switch (entry.category) {
          _racePodiumCategory => await raceFetcher(entry.round),
          _qualifyingTop3Category => await qualifyingFetcher(entry.round),
          _ => const <String>[],
        };
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
