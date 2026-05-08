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
    });

    test('returns notice when hosted build is newer', () async {
      final client = MockClient(
        (_) async => http.Response(
          '''
          {
            "android": {
              "latestBuild": 7,
              "latestVersion": "1.2.2",
              "releaseNotes": "Fresh race fixes."
            }
          }
          ''',
          200,
        ),
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
  });
}
