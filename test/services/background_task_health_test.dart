import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/services/background_task_health.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BackgroundTaskHealth.getSnapshot', () {
    test('returns zero failures and null timestamps on a fresh install',
        () async {
      final snapshot = await BackgroundTaskHealth.getSnapshot();
      expect(snapshot.consecutiveFailures, 0);
      expect(snapshot.lastSuccessAt, isNull);
      expect(snapshot.lastFailureAt, isNull);
      expect(snapshot.lastErrorMessage, isNull);
      expect(snapshot.isStale, isFalse);
    });
  });

  group('BackgroundTaskHealth.recordFailure', () {
    test('increments the consecutive failure counter on each call', () async {
      await BackgroundTaskHealth.recordFailure(Exception('first'), null);
      await BackgroundTaskHealth.recordFailure(Exception('second'), null);

      final snapshot = await BackgroundTaskHealth.getSnapshot();
      expect(snapshot.consecutiveFailures, 2);
      expect(snapshot.lastFailureAt, isNotNull);
      expect(snapshot.lastErrorMessage, contains('second'));
    });

    test('flags the snapshot as stale once the threshold is hit', () async {
      for (var i = 0; i < BackgroundTaskHealth.staleFailureThreshold; i++) {
        await BackgroundTaskHealth.recordFailure(Exception('boom $i'), null);
      }

      final snapshot = await BackgroundTaskHealth.getSnapshot();
      expect(
        snapshot.consecutiveFailures,
        BackgroundTaskHealth.staleFailureThreshold,
      );
      expect(snapshot.isStale, isTrue);
    });

    test('records the most recent error message, overwriting older ones',
        () async {
      await BackgroundTaskHealth.recordFailure(Exception('old'), null);
      await BackgroundTaskHealth.recordFailure(Exception('new'), null);

      final snapshot = await BackgroundTaskHealth.getSnapshot();
      expect(snapshot.lastErrorMessage, contains('new'));
      expect(snapshot.lastErrorMessage, isNot(contains('old')));
    });
  });

  group('BackgroundTaskHealth.recordSuccess', () {
    test('resets the consecutive failure counter to zero', () async {
      await BackgroundTaskHealth.recordFailure(Exception('boom'), null);
      await BackgroundTaskHealth.recordFailure(Exception('boom'), null);
      await BackgroundTaskHealth.recordSuccess();

      final snapshot = await BackgroundTaskHealth.getSnapshot();
      expect(snapshot.consecutiveFailures, 0);
      expect(snapshot.isStale, isFalse);
    });

    test('clears the last error message but keeps the last failure timestamp',
        () async {
      await BackgroundTaskHealth.recordFailure(Exception('boom'), null);
      final beforeFailure = await BackgroundTaskHealth.getSnapshot();

      await BackgroundTaskHealth.recordSuccess();
      final afterSuccess = await BackgroundTaskHealth.getSnapshot();

      expect(afterSuccess.lastErrorMessage, isNull);
      expect(afterSuccess.lastSuccessAt, isNotNull);
      // Last failure timestamp is preserved so we can tell when the last
      // outage was even after a recovery.
      expect(afterSuccess.lastFailureAt, beforeFailure.lastFailureAt);
    });

    test('a success after the stale threshold un-stales the snapshot',
        () async {
      for (var i = 0; i <= BackgroundTaskHealth.staleFailureThreshold; i++) {
        await BackgroundTaskHealth.recordFailure(Exception('boom $i'), null);
      }
      expect(
        (await BackgroundTaskHealth.getSnapshot()).isStale,
        isTrue,
        reason: 'precondition: setup hit the stale threshold',
      );

      await BackgroundTaskHealth.recordSuccess();

      final snapshot = await BackgroundTaskHealth.getSnapshot();
      expect(snapshot.isStale, isFalse);
      expect(snapshot.consecutiveFailures, 0);
    });
  });
}
