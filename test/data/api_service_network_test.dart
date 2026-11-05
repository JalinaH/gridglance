import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/data/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Body for `/{season}/{round}/results/` with the given podium.
String _resultsBody(List<String> driverIds) => jsonEncode({
  'MRData': {
    'RaceTable': {
      'Races': [
        {
          'Results': [
            for (final id in driverIds)
              {
                'Driver': {'driverId': id},
              },
          ],
        },
      ],
    },
  },
});

void main() {
  final podium = _resultsBody(['norris', 'piastri', 'verstappen']);

  Future<T> withClient<T>(
    Future<T> Function() body,
    Future<http.Response> Function(http.Request) handler,
  ) {
    return http.runWithClient(body, () => MockClient(handler));
  }

  group('ApiService non-cached endpoints', () {
    test('retries a 5xx response and returns the next success', () async {
      var calls = 0;
      final ids = await withClient(
        () => ApiService().getRaceTop3DriverIds(season: '2026', round: '5'),
        (_) async => ++calls == 1
            ? http.Response('busy', 503)
            : http.Response(podium, 200),
      );

      expect(calls, 2);
      expect(ids, ['norris', 'piastri', 'verstappen']);
    });

    test('retries transient network errors', () async {
      var calls = 0;
      final ids = await withClient(
        () => ApiService().getRaceTop3DriverIds(season: '2026', round: '5'),
        (_) async {
          if (++calls < 3) throw http.ClientException('connection reset');
          return http.Response(podium, 200);
        },
      );

      expect(calls, 3);
      expect(ids, hasLength(3));
    });

    test('does not retry a 404 and returns no podium', () async {
      var calls = 0;
      final ids = await withClient(
        () => ApiService().getRaceTop3DriverIds(season: '2026', round: '99'),
        (_) async {
          calls++;
          return http.Response('not found', 404);
        },
      );

      expect(calls, 1);
      expect(ids, isEmpty);
    });

    test('gives up after the retry budget on persistent 5xx', () async {
      var calls = 0;
      await expectLater(
        withClient(
          () => ApiService().getQualifyingTop3DriverIds(
            season: '2026',
            round: '5',
          ),
          (_) async {
            calls++;
            return http.Response('down', 502);
          },
        ),
        throwsException,
      );

      expect(calls, 3);
    });

    testWidgets('times out a request that never responds', (tester) async {
      var calls = 0;
      Object? error;
      unawaited(
        withClient(
          () =>
              ApiService().getDriverResults(season: '2026', driverId: 'norris'),
          (_) {
            calls++;
            return Completer<http.Response>().future;
          },
        ).catchError((Object e) {
          error = e;
          return const <Never>[];
        }),
      );

      // 3 attempts x 10s timeout plus backoff, all on the fake clock.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(calls, 3);
      expect(error, isA<TimeoutException>());
    });
  });
}
