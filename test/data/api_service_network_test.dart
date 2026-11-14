import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/data/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('ApiService paged results', () {
    Map<String, dynamic> row(String familyName) => {
      'position': '1',
      'points': '25',
      'Driver': {'givenName': 'Test', 'familyName': familyName},
    };

    Map<String, dynamic> race(String round, List<String> drivers) => {
      'season': '2026',
      'round': round,
      'raceName': 'Round $round',
      'date': '2026-03-0$round',
      'Results': drivers.map(row).toList(),
    };

    String page({
      required int limit,
      required int offset,
      required int total,
      required List<Map<String, dynamic>> races,
    }) => jsonEncode({
      'MRData': {
        'limit': '$limit',
        'offset': '$offset',
        'total': '$total',
        'RaceTable': {'Races': races},
      },
    });

    test('asks for the largest page instead of the default 30 rows', () async {
      final requested = <Uri>[];
      await withClient(
        () => ApiService().getConstructorResults(
          season: '2026',
          constructorId: 'mclaren',
        ),
        (request) async {
          requested.add(request.url);
          return http.Response(
            page(
              limit: 100,
              offset: 0,
              total: 2,
              races: [
                race('1', ['Norris', 'Piastri']),
              ],
            ),
            200,
          );
        },
      );

      expect(requested, hasLength(1));
      expect(requested.single.queryParameters['limit'], '100');
      expect(requested.single.queryParameters['offset'], '0');
    });

    test('follows offset until every row is loaded', () async {
      final offsets = <String?>[];
      // The server caps the page at 3 rows, so 5 rows span two pages and
      // round 2 is split across them.
      final results = await withClient(
        () => ApiService().getConstructorResults(
          season: '2026',
          constructorId: 'mclaren',
        ),
        (request) async {
          final offset = request.url.queryParameters['offset'];
          offsets.add(offset);
          if (offset == '0') {
            return http.Response(
              page(
                limit: 3,
                offset: 0,
                total: 5,
                races: [
                  race('1', ['Norris', 'Piastri']),
                  race('2', ['Norris']),
                ],
              ),
              200,
            );
          }
          return http.Response(
            page(
              limit: 3,
              offset: 3,
              total: 5,
              races: [
                race('2', ['Piastri']),
                race('3', ['Norris']),
              ],
            ),
            200,
          );
        },
      );

      expect(offsets, ['0', '3']);
      expect(results.map((r) => r.round), ['1', '2', '3']);
      expect(results[1].drivers.map((d) => d.familyName), [
        'Norris',
        'Piastri',
      ]);
    });

    test('stops after one page when the response has no total', () async {
      var calls = 0;
      final results = await withClient(
        () => ApiService().getConstructorResults(
          season: '2026',
          constructorId: 'mclaren',
        ),
        (_) async {
          calls++;
          return http.Response(
            jsonEncode({
              'MRData': {
                'RaceTable': {
                  'Races': [
                    race('1', ['Norris', 'Piastri']),
                  ],
                },
              },
            }),
            200,
          );
        },
      );

      expect(calls, 1);
      expect(results, hasLength(1));
    });

    test('standings request more than the default 30 rows', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      Uri? requested;
      await withClient(() => ApiService().getDriverStandings(season: '2026'), (
        request,
      ) async {
        requested = request.url;
        return http.Response(
          jsonEncode({
            'MRData': {
              'StandingsTable': {'StandingsLists': <Object>[]},
            },
          }),
          200,
        );
      });

      expect(requested?.queryParameters['limit'], '100');
    });
  });

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

  group('ApiService off-season standings', () {
    String driverStandings(List<String> ids) => jsonEncode({
      'MRData': {
        'StandingsTable': {
          'StandingsLists': ids.isEmpty
              ? <Object>[]
              : [
                  {
                    'DriverStandings': [
                      for (final id in ids)
                        {
                          'position': '1',
                          'points': '10',
                          'wins': '0',
                          'Driver': {
                            'driverId': id,
                            'givenName': 'Test',
                            'familyName': id,
                          },
                          'Constructors': <Object>[],
                        },
                    ],
                  },
                ],
        },
      },
    });

    const empty = '{"MRData":{"StandingsTable":{"StandingsLists":[]}}}';

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('uses the requested season when it has standings', () async {
      final seasons = <String>{};
      final standings = await withClient(
        () => ApiService().getStandingsOrPreviousSeason(season: '2026'),
        (request) async {
          seasons.add(request.url.pathSegments[2]);
          return http.Response(
            request.url.path.contains('driverstandings')
                ? driverStandings(['norris'])
                : empty,
            200,
          );
        },
      );

      expect(seasons, {'2026'});
      expect(standings.season, '2026');
      expect(standings.isPreviousSeason, isFalse);
      expect(standings.drivers.data.single.driverId, 'norris');
    });

    test('falls back to last season before the first race', () async {
      final standings = await withClient(
        () => ApiService().getStandingsOrPreviousSeason(season: '2027'),
        (request) async => http.Response(
          request.url.path.contains('/2026/driverstandings')
              ? driverStandings(['norris'])
              : empty,
          200,
        ),
      );

      expect(standings.requestedSeason, '2027');
      expect(standings.season, '2026');
      expect(standings.isPreviousSeason, isTrue);
      expect(standings.drivers.data.single.driverId, 'norris');
    });

    test(
      'stays on the requested season when last season is empty too',
      () async {
        final standings = await withClient(
          () => ApiService().getStandingsOrPreviousSeason(season: '2027'),
          (_) async => http.Response(empty, 200),
        );

        expect(standings.season, '2027');
        expect(standings.isPreviousSeason, isFalse);
        expect(standings.drivers.data, isEmpty);
      },
    );

    test('stays on the requested season when the fallback fails', () async {
      final standings = await withClient(
        () => ApiService().getStandingsOrPreviousSeason(season: '2027'),
        (request) async => request.url.path.contains('/2027/')
            ? http.Response(empty, 200)
            : http.Response('nope', 404),
      );

      expect(standings.season, '2027');
      expect(standings.isPreviousSeason, isFalse);
    });

    test('season overview flags the off-season', () async {
      final overview = await withClient(
        () => ApiService().getSeasonOverview(season: '2027'),
        (request) async {
          final path = request.url.path;
          if (path.contains('/2026/driverstandings')) {
            return http.Response(driverStandings(['norris']), 200);
          }
          if (path.contains('standings')) return http.Response(empty, 200);
          return http.Response('{"MRData":{"RaceTable":{"Races":[]}}}', 200);
        },
      );

      expect(overview.isOffSeason, isTrue);
      expect(overview.standingsSeason, '2026');
      expect(overview.driverStandings, hasLength(1));
    });
  });
}
