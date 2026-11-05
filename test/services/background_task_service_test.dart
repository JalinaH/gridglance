import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/services/background_task_health.dart';
import 'package:gridglance/services/background_task_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const androidTask = BackgroundTaskService.androidPeriodicTaskName;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BackgroundTaskService.runTask', () {
    test('refreshes widgets before checking favorite alerts', () async {
      final calls = <String>[];
      final ok = await BackgroundTaskService.runTask(
        androidTask,
        refreshWidgets: () async => calls.add('widgets'),
        checkFavoriteAlerts: () async => calls.add('alerts'),
      );

      expect(ok, isTrue);
      expect(calls, ['widgets', 'alerts']);
      final snapshot = await BackgroundTaskHealth.getSnapshot();
      expect(snapshot.lastSuccessAt, isNotNull);
      expect(snapshot.consecutiveFailures, 0);
    });

    test('still checks alerts when the widget refresh fails', () async {
      var alertsChecked = false;
      final ok = await BackgroundTaskService.runTask(
        androidTask,
        refreshWidgets: () async => throw StateError('widgets down'),
        checkFavoriteAlerts: () async => alertsChecked = true,
      );

      expect(ok, isFalse);
      expect(alertsChecked, isTrue);
      final snapshot = await BackgroundTaskHealth.getSnapshot();
      expect(snapshot.consecutiveFailures, 1);
      expect(snapshot.lastErrorMessage, contains('widgets down'));
    });

    test('still refreshes widgets when alert setup fails', () async {
      var widgetsRefreshed = false;
      final ok = await BackgroundTaskService.runTask(
        androidTask,
        refreshWidgets: () async => widgetsRefreshed = true,
        checkFavoriteAlerts: () async => throw StateError('notifications'),
      );

      expect(ok, isFalse);
      expect(widgetsRefreshed, isTrue);
    });

    test('records the first failure when several steps fail', () async {
      await BackgroundTaskService.runTask(
        androidTask,
        refreshWidgets: () async => throw StateError('first'),
        checkFavoriteAlerts: () async => throw StateError('second'),
      );

      final snapshot = await BackgroundTaskHealth.getSnapshot();
      expect(snapshot.lastErrorMessage, contains('first'));
    });

    test('reschedules only for iOS background task identifiers', () async {
      var rescheduled = 0;
      Future<void> noop() async {}

      await BackgroundTaskService.runTask(
        androidTask,
        refreshWidgets: noop,
        checkFavoriteAlerts: noop,
        rescheduleIOS: () async => rescheduled++,
      );
      expect(rescheduled, 0);

      await BackgroundTaskService.runTask(
        BackgroundTaskService.iOSBgProcessingTaskIdentifier,
        refreshWidgets: noop,
        checkFavoriteAlerts: noop,
        rescheduleIOS: () async => rescheduled++,
      );
      expect(rescheduled, 1);
    });
  });
}
