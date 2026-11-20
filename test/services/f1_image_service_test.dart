import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/services/f1_image_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final service = F1ImageService.instance;

  group('F1ImageService.carImageUrl', () {
    // Constructor IDs Jolpica reports for the 2026 season.
    const constructors2026 = {
      'alpine': 'alpine',
      'aston_martin': 'astonmartin',
      'audi': 'audi',
      'cadillac': 'cadillac',
      'ferrari': 'ferrari',
      'haas': 'haasf1team',
      'mclaren': 'mclaren',
      'mercedes': 'mercedes',
      'rb': 'racingbulls',
      'red_bull': 'redbullracing',
      'williams': 'williams',
    };

    test('maps every 2026 constructor to its F1 media path', () {
      final season = service.carImageSeason;
      for (final entry in constructors2026.entries) {
        final url = service.carImageUrl(entry.key);
        expect(url, isNotNull, reason: entry.key);
        expect(
          url,
          endsWith(
            '/common/f1/$season/${entry.value}/$season${entry.value}carright.webp',
          ),
          reason: entry.key,
        );
      }
    });

    test('falls back to the baseline generic car, which always exists', () {
      expect(
        service.carImageUrl('mclaren'),
        contains('/d_common:f1:2026:fallback:car:2026fallbackcarright.webp/'),
      );
    });

    test('requests PNG so native widgets can decode the bytes', () {
      expect(service.carImageUrl('mclaren'), contains('/f_png/'));
    });

    test('never points at the retired 2025 asset path', () {
      expect(service.carImageUrl('ferrari'), isNot(contains('fom-website')));
    });

    test('maps legacy sauber to the Audi car', () {
      expect(service.carImageUrl('sauber'), service.carImageUrl('audi'));
    });

    test('returns null for unknown constructors', () {
      expect(service.carImageUrl('brawn'), isNull);
    });
  });

  group('F1ImageService.init', () {
    const cacheKey = 'f1_image_service_v1';

    String cache({required Duration age}) => jsonEncode({
      'saved_at': DateTime.now().subtract(age).toIso8601String(),
      'by_number': {'4': 'https://img.test/norris.png'},
      'by_code': {'NOR': 'https://img.test/norris.png'},
    });

    final apiBody = jsonEncode([
      {
        'driver_number': 81,
        'name_acronym': 'PIA',
        'headshot_url': 'https://img.test/piastri.png',
      },
    ]);

    Future<void> initWith(
      Future<http.Response> Function(http.Request) handler,
    ) => http.runWithClient(service.init, () => MockClient(handler));

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      service.resetForTesting();
    });

    test('keeps a stale cache when the network is down', () async {
      SharedPreferences.setMockInitialValues({
        cacheKey: cache(age: const Duration(days: 3)),
      });

      await initWith((_) async => throw http.ClientException('offline'));
      await pumpEventQueue();

      expect(
        service.driverHeadshotUrl(permanentNumber: '4'),
        'https://img.test/norris.png',
      );
      expect(service.driverHeadshotUrl(code: 'nor'), isNotNull);
    });

    test('does not wait for the network when a stale cache exists', () async {
      SharedPreferences.setMockInitialValues({
        cacheKey: cache(age: const Duration(days: 3)),
      });

      // The request never completes; init must still return.
      await initWith(
        (_) => Completer<http.Response>().future,
      ).timeout(const Duration(seconds: 1));

      expect(service.driverHeadshotUrl(permanentNumber: '4'), isNotNull);
    });

    test('refreshes a stale cache in the background', () async {
      SharedPreferences.setMockInitialValues({
        cacheKey: cache(age: const Duration(days: 3)),
      });

      await initWith((_) async => http.Response(apiBody, 200));
      await pumpEventQueue();

      expect(
        service.driverHeadshotUrl(permanentNumber: '81'),
        'https://img.test/piastri.png',
      );
    });

    test('skips the network while the cache is fresh', () async {
      SharedPreferences.setMockInitialValues({
        cacheKey: cache(age: const Duration(hours: 1)),
      });
      var calls = 0;

      await initWith((_) async {
        calls++;
        return http.Response(apiBody, 200);
      });
      await pumpEventQueue();

      expect(calls, 0);
      expect(service.driverHeadshotUrl(permanentNumber: '4'), isNotNull);
    });

    test('fetches on first launch with nothing cached', () async {
      SharedPreferences.setMockInitialValues({});

      await initWith((_) async => http.Response(apiBody, 200));

      expect(service.driverHeadshotUrl(code: 'PIA'), isNotNull);
    });

    test('an empty response does not wipe cached headshots', () async {
      SharedPreferences.setMockInitialValues({
        cacheKey: cache(age: const Duration(days: 3)),
      });

      await initWith((_) async => http.Response('[]', 200));
      await pumpEventQueue();

      expect(service.driverHeadshotUrl(permanentNumber: '4'), isNotNull);
    });
  });

  group('F1ImageService car image season', () {
    const seasonKey = 'f1_image_service_car_season_v1';
    const checkedKey = 'f1_image_service_car_season_checked_at_v1';

    Future<List<int>> resolve(
      int Function(int year) statusFor, {
      required DateTime now,
    }) async {
      final probed = <int>[];
      F1ImageService.clock = () => now;
      await http.runWithClient(
        service.resolveCarImageSeasonForTesting,
        () => MockClient((request) async {
          final year = int.parse(request.url.pathSegments[5]);
          probed.add(year);
          return http.Response('', statusFor(year));
        }),
      );
      return probed;
    }

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      service.resetForTesting();
    });
    tearDown(service.resetForTesting);

    test('moves to a new season once its artwork is published', () async {
      SharedPreferences.setMockInitialValues({});

      final probed = await resolve(
        (year) => year <= 2027 ? 200 : 404,
        now: DateTime(2027, 3, 1),
      );

      expect(probed, [2027]);
      expect(service.carImageSeason, 2027);
      expect(service.carImageUrl('mclaren'), contains('/2027/mclaren/'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(seasonKey), 2027);
    });

    test('stays on the newest published season before launch', () async {
      SharedPreferences.setMockInitialValues({});

      final probed = await resolve(
        (year) => year <= 2026 ? 200 : 404,
        now: DateTime(2028, 1, 10),
      );

      expect(probed, [2028, 2027]);
      expect(service.carImageSeason, 2026);
    });

    test('checks at most once a day', () async {
      final now = DateTime(2027, 3, 1, 12);
      SharedPreferences.setMockInitialValues({
        seasonKey: 2027,
        checkedKey: now
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch,
      });

      final probed = await resolve((_) => 200, now: now);

      expect(probed, isEmpty);
      expect(service.carImageSeason, 2027);
    });

    test('keeps the known season when the check fails', () async {
      SharedPreferences.setMockInitialValues({seasonKey: 2027});

      await resolve((_) => 503, now: DateTime(2028, 3, 1));

      expect(service.carImageSeason, 2027);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(checkedKey), isNull);
    });

    test('never probes seasons at or below the known one', () async {
      SharedPreferences.setMockInitialValues({seasonKey: 2027});

      final probed = await resolve((_) => 200, now: DateTime(2027, 6, 1));

      expect(probed, isEmpty);
      expect(service.carImageSeason, 2027);
    });
  });
}
