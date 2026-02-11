import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/services/prediction_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PredictionService.scoreTop3Prediction', () {
    test(
      'awards 3 points for exact positions and 1 for wrong-order matches',
      () {
        final score = PredictionService.scoreTop3Prediction(
          predictedIds: const ['norris', 'verstappen', 'leclerc'],
          actualIds: const ['verstappen', 'norris', 'leclerc'],
        );

        expect(score, 5);
      },
    );

    test('returns zero for empty values', () {
      final score = PredictionService.scoreTop3Prediction(
        predictedIds: const [],
        actualIds: const ['hamilton', 'russell', 'piastri'],
      );

      expect(score, 0);
    });
  });

  group('PredictionService.getSeasonScore', () {
    test('aggregates graded points and pending predictions', () async {
      SharedPreferences.setMockInitialValues({
        'prediction_v1|2026|1|race_podium': <String>[
          'verstappen',
          'norris',
          'leclerc',
        ],
        'prediction_v1|2026|1|qualifying_top3': <String>[
          'norris',
          'verstappen',
          'leclerc',
        ],
        'prediction_v1|2026|2|race_podium': <String>[
          'piastri',
          'sainz',
          'hamilton',
        ],
      });

      final service = PredictionService();
      final score = await service.getSeasonScore(
        season: '2026',
        raceTop3Fetcher: (round) async {
          if (round == '1') {
            return const ['verstappen', 'norris', 'leclerc'];
          }
          if (round == '2') {
            return const [];
          }
          return const [];
        },
        qualifyingTop3Fetcher: (round) async {
          if (round == '1') {
            return const ['verstappen', 'norris', 'leclerc'];
          }
          return const [];
        },
      );

      expect(score.totalPoints, 14);
      expect(score.gradedPredictions, 2);
      expect(score.pendingPredictions, 1);
      expect(score.totalPredictions, 3);
    });

    test('treats fetch failures as pending predictions', () async {
      SharedPreferences.setMockInitialValues({
        'prediction_v1|2026|3|qualifying_top3': <String>[
          'hamilton',
          'russell',
          'leclerc',
        ],
      });

      final service = PredictionService();
      final score = await service.getSeasonScore(
        season: '2026',
        qualifyingTop3Fetcher: (_) async {
          throw Exception('network down');
        },
      );

      expect(score.totalPoints, 0);
      expect(score.gradedPredictions, 0);
      expect(score.pendingPredictions, 1);
    });
  });

  group('PredictionService.set/get', () {
    test('stores and returns normalized top-3 picks', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PredictionService();

      await service.setRacePodiumPrediction(
        season: '2026',
        round: '7',
        driverIds: const ['norris', 'norris', 'piastri', 'leclerc'],
      );

      final stored = await service.getRacePodiumPrediction(
        season: '2026',
        round: '7',
      );
      expect(stored, const ['norris', 'piastri', 'leclerc']);
    });

    test('rejects incomplete top-3 predictions', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PredictionService();

      expect(
        () => service.setQualifyingTop3Prediction(
          season: '2026',
          round: '8',
          driverIds: const ['norris', 'piastri'],
        ),
        throwsArgumentError,
      );
    });
  });
}
