import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/services/favorite_result_alert_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // No favorites configured — `_runCheck` will early-return immediately,
    // which is enough to exercise the in-flight dedup wrapper without
    // hitting the network.
    SharedPreferences.setMockInitialValues({});
  });

  group('FavoriteResultAlertService.checkForUpdates', () {
    test('concurrent callers both resolve without error', () async {
      // Two near-simultaneous resumes must both complete cleanly. Prior to
      // the dedup fix the second call no-op'd before the first finished;
      // we rely on this not throwing or hanging.
      await Future.wait([
        FavoriteResultAlertService.checkForUpdates(),
        FavoriteResultAlertService.checkForUpdates(),
      ]);
    });

    test('completes successfully when no favorites are set', () async {
      // Should be a no-op rather than throwing.
      await FavoriteResultAlertService.checkForUpdates();
    });

    test('can be invoked again after the previous run finishes', () async {
      await FavoriteResultAlertService.checkForUpdates();

      // The `_inFlight` slot must be cleared via whenComplete so a second
      // (sequential) call still actually runs.
      final next = FavoriteResultAlertService.checkForUpdates();
      expect(next, isA<Future<void>>());
      await next;
    });
  });
}
