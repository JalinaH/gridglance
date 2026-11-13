import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/services/app_update_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppUpdateService.checkForUpdate', () {
    late AppUpdateService service;

    setUp(() {
      service = AppUpdateService();
      SharedPreferences.setMockInitialValues({});
      AppUpdateService.resetForTesting();
    });

    tearDown(AppUpdateService.resetForTesting);

    group('config problems', () {
      late List<String> reported;

      setUp(() {
        reported = [];
        AppUpdateService.configProblemReporter = (reason, _) {
          reported.add(reason);
        };
      });

      Future<void> check(http.Client client) => service.checkForUpdate(
        client: client,
        installedBuildNumber: '6',
        platform: 'android',
      );

      test('reports a missing config file', () async {
        await check(MockClient((_) async => http.Response('Not found', 404)));

        expect(reported, ['http-404']);
      });

      test('reports a config that is not JSON', () async {
        await check(MockClient((_) async => http.Response('<html>', 200)));

        expect(reported, ['invalid-json']);
      });

      test('reports a config that is not a JSON object', () async {
        await check(MockClient((_) async => http.Response('[]', 200)));

        expect(reported, ['invalid-json']);
      });

      test('reports only once per app run', () async {
        final client = MockClient((_) async => http.Response('gone', 404));
        await check(client);
        await check(client);

        expect(reported, hasLength(1));
      });

      test('stays quiet on server errors and network failures', () async {
        await check(MockClient((_) async => http.Response('busy', 503)));
        await check(
          MockClient((_) async => throw http.ClientException('offline')),
        );

        expect(reported, isEmpty);
      });

      test('stays quiet when the config is valid', () async {
        await check(
          MockClient(
            (_) async => http.Response('{"android":{"latestBuild":7}}', 200),
          ),
        );

        expect(reported, isEmpty);
      });
    });

    test('returns notice when hosted build is newer', () async {
      final client = MockClient(
        (_) async => http.Response('''
          {
            "android": {
              "latestBuild": 7,
              "latestVersion": "1.2.2",
              "releaseNotes": "Fresh race fixes."
            }
          }
          ''', 200),
      );

      final notice = await service.checkForUpdate(
        client: client,
        installedBuildNumber: '6',
      );

      expect(notice, isNotNull);
      expect(notice!.latestBuild, 7);
      expect(notice.latestVersion, '1.2.2');
      expect(notice.releaseNotes, 'Fresh race fixes.');
      expect(notice.storeUrl, AppUpdateService.defaultStoreUri);
    });

    test('returns null when installed build is current', () async {
      final client = MockClient(
        (_) async => http.Response(
          '{"android":{"latestBuild":7,"latestVersion":"1.2.2"}}',
          200,
        ),
      );

      final notice = await service.checkForUpdate(
        client: client,
        installedBuildNumber: '7',
      );

      expect(notice, isNull);
    });

    test('returns null after the same update build is dismissed', () async {
      final prefs = await SharedPreferences.getInstance();
      final client = MockClient(
        (_) async => http.Response(
          '{"android":{"latestBuild":8,"latestVersion":"1.2.3"}}',
          200,
        ),
      );
      final notice = AppUpdateNotice(
        latestBuild: 8,
        latestVersion: '1.2.3',
        releaseNotes: 'Later.',
        storeUrl: AppUpdateService.defaultStoreUri,
      );

      await service.dismiss(notice);
      final result = await service.checkForUpdate(
        client: client,
        preferences: prefs,
        installedBuildNumber: '7',
      );

      expect(result, isNull);
    });

    test('returns null on malformed response', () async {
      final client = MockClient((_) async => http.Response('[]', 200));

      final notice = await service.checkForUpdate(
        client: client,
        installedBuildNumber: '6',
      );

      expect(notice, isNull);
    });

    test('iOS reads the ios block and its store link', () async {
      final client = MockClient(
        (_) async => http.Response(
          '{"android":{"latestBuild":9},'
          '"ios":{"latestBuild":8,"storeUrl":"https://apps.apple.com/app/id123"}}',
          200,
        ),
      );

      final notice = await service.checkForUpdate(
        client: client,
        installedBuildNumber: '7',
        platform: 'ios',
      );

      expect(notice, isNotNull);
      expect(notice!.latestBuild, 8);
      expect(notice.storeUrl, Uri.parse('https://apps.apple.com/app/id123'));
    });

    test('iOS ignores android-only config', () async {
      final client = MockClient(
        (_) async => http.Response('{"android":{"latestBuild":9}}', 200),
      );

      final notice = await service.checkForUpdate(
        client: client,
        installedBuildNumber: '7',
        platform: 'ios',
      );

      expect(notice, isNull);
    });

    test('iOS never falls back to the Play Store link', () async {
      final client = MockClient(
        (_) async => http.Response('{"ios":{"latestBuild":9}}', 200),
      );

      final notice = await service.checkForUpdate(
        client: client,
        installedBuildNumber: '7',
        platform: 'ios',
      );

      expect(notice, isNull);
    });

    test('Android still accepts the legacy flat format', () async {
      final client = MockClient(
        (_) async => http.Response('{"latestBuild":9}', 200),
      );

      final notice = await service.checkForUpdate(
        client: client,
        installedBuildNumber: '7',
        platform: 'android',
      );

      expect(notice?.storeUrl, AppUpdateService.defaultStoreUri);
    });
  });
}
