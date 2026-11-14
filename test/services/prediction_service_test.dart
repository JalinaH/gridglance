import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/models/driver_standing.dart';
import 'package:gridglance/services/prediction_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(PredictionService.resetForTesting);
  tearDown(PredictionService.resetForTesting);

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

  group('PredictionService result caching', () {
    const podium = ['verstappen', 'norris', 'leclerc'];
    final raceDay = DateTime(2026, 3, 8, 18);

    Map<String, Object> onePrediction() => {
      'prediction_v1|2026|1|race_podium': <String>[...podium],
    };

    test('does not refetch a result it checked recently', () async {
      SharedPreferences.setMockInitialValues(onePrediction());
      PredictionService.clock = () => raceDay;
      var calls = 0;
      Future<List<String>> fetcher(String _) async {
        calls++;
        return podium;
      }

      final service = PredictionService();
      await service.getSeasonScore(season: '2026', raceTop3Fetcher: fetcher);
      final second = await service.getSeasonScore(
        season: '2026',
        raceTop3Fetcher: fetcher,
      );

      expect(calls, 1);
      expect(second.totalPoints, 9);
      expect(second.gradedPredictions, 1);
    });

    test('re-checks an unsettled result and picks up a penalty', () async {
      SharedPreferences.setMockInitialValues(onePrediction());
      var now = raceDay;
      PredictionService.clock = () => now;
      var actual = podium;
      Future<List<String>> fetcher(String _) async => actual;

      final service = PredictionService();
      await service.getSeasonScore(season: '2026', raceTop3Fetcher: fetcher);

      // Next morning the winner is disqualified.
      now = raceDay.add(const Duration(hours: 14));
      actual = const ['norris', 'leclerc', 'piastri'];
      final score = await service.getSeasonScore(
        season: '2026',
        raceTop3Fetcher: fetcher,
      );

      expect(score.totalPoints, 2);
    });

    test('treats a result as final once it has settled', () async {
      SharedPreferences.setMockInitialValues(onePrediction());
      var now = raceDay;
      PredictionService.clock = () => now;
      var calls = 0;
      Future<List<String>> fetcher(String _) async {
        calls++;
        return podium;
      }

      final service = PredictionService();
      await service.getSeasonScore(season: '2026', raceTop3Fetcher: fetcher);
      now = raceDay.add(const Duration(days: 30));
      await service.getSeasonScore(season: '2026', raceTop3Fetcher: fetcher);

      expect(calls, 1);
    });

    test('keeps a stored result when a re-check fails', () async {
      SharedPreferences.setMockInitialValues(onePrediction());
      var now = raceDay;
      PredictionService.clock = () => now;
      var fail = false;
      Future<List<String>> fetcher(String _) async {
        if (fail) throw Exception('rate limited');
        return podium;
      }

      final service = PredictionService();
      await service.getSeasonScore(season: '2026', raceTop3Fetcher: fetcher);
      now = raceDay.add(const Duration(hours: 14));
      fail = true;
      final score = await service.getSeasonScore(
        season: '2026',
        raceTop3Fetcher: fetcher,
      );

      expect(score.gradedPredictions, 1);
      expect(score.totalPoints, 9);
    });

    test('waits before asking again for a session with no result', () async {
      SharedPreferences.setMockInitialValues(onePrediction());
      var now = raceDay;
      PredictionService.clock = () => now;
      var calls = 0;
      Future<List<String>> fetcher(String _) async {
        calls++;
        return const [];
      }

      final service = PredictionService();
      await service.getSeasonScore(season: '2026', raceTop3Fetcher: fetcher);
      await service.getSeasonScore(season: '2026', raceTop3Fetcher: fetcher);
      expect(calls, 1);

      now = raceDay.add(const Duration(minutes: 11));
      final score = await service.getSeasonScore(
        season: '2026',
        raceTop3Fetcher: fetcher,
      );
      expect(calls, 2);
      expect(score.pendingPredictions, 1);
    });

    test('stored results are not mistaken for predictions', () async {
      SharedPreferences.setMockInitialValues(onePrediction());
      PredictionService.clock = () => raceDay;

      final service = PredictionService();
      await service.getSeasonScore(
        season: '2026',
        raceTop3Fetcher: (_) async => podium,
      );
      final score = await service.getSeasonScore(
        season: '2026',
        raceTop3Fetcher: (_) async => podium,
      );

      expect(score.totalPredictions, 1);
    });
  });

  group('PredictionService.getPredictionDrivers', () {
    List<DriverStanding> grid(String prefix) => [
      for (var i = 1; i <= 3; i++)
        DriverStanding.fromJson({
          'position': '$i',
          'points': '0',
          'wins': '0',
          'Driver': {
            'driverId': '$prefix$i',
            'givenName': 'Driver',
            'familyName': '$prefix$i',
          },
          'Constructors': <Object>[],
        }),
    ];

    test('uses the current season when it has standings', () async {
      final asked = <String>[];
      final drivers = await PredictionService().getPredictionDrivers(
        season: '2026',
        standingsFetcher: (season) async {
          asked.add(season);
          return grid('now');
        },
      );

      expect(asked, ['2026']);
      expect(drivers.first.driverId, 'now1');
    });

    test('falls back to last season before round 1 is scored', () async {
      final drivers = await PredictionService().getPredictionDrivers(
        season: '2027',
        standingsFetcher: (season) async =>
            season == '2027' ? const [] : grid('last'),
      );

      expect(drivers, hasLength(3));
      expect(drivers.first.driverId, 'last1');
    });

    test('falls back when the current season fails to load', () async {
      final drivers = await PredictionService().getPredictionDrivers(
        season: '2027',
        standingsFetcher: (season) async {
          if (season == '2027') throw Exception('offline');
          return grid('last');
        },
      );

      expect(drivers, hasLength(3));
    });

    test('returns nothing when neither season has drivers', () async {
      final drivers = await PredictionService().getPredictionDrivers(
        season: '2027',
        standingsFetcher: (_) async => const [],
      );

      expect(drivers, isEmpty);
    });
  });
}
