import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';

import 'background_task_health.dart';
import 'crash_reporting.dart';
import 'favorite_result_alert_service.dart';
import 'notification_service.dart';
import 'widget_update_service.dart';

@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await CrashReporting.initForBackground();
    return BackgroundTaskService.runTask(task);
  });
}

/// A single unit of background work. Steps run independently so one
/// failure (e.g. notification setup) can't stop the others (e.g. widgets).
typedef BackgroundStep = Future<void> Function();

class BackgroundTaskService {
  static const String androidPeriodicUniqueName =
      'gridglance.favorite_results.periodic';
  static const String androidPeriodicTaskName =
      'gridglance.favorite_results.periodic.task';
  static const String iOSBgProcessingTaskIdentifier =
      'com.gridglance.app.favorite-result-sync';

  static bool _initialized = false;

  /// Runs one background pass and returns the Workmanager result.
  ///
  /// Widgets refresh first and independently of notifications and alerts:
  /// a failure in one step is recorded and reported but never skips the
  /// next. The pass only counts as healthy when every step succeeded.
  static Future<bool> runTask(
    String task, {
    BackgroundStep? refreshWidgets,
    BackgroundStep? checkFavoriteAlerts,
    BackgroundStep? rescheduleIOS,
  }) async {
    final steps = <String, BackgroundStep>{
      'widgets': refreshWidgets ?? _refreshWidgets,
      'favorite_alerts': checkFavoriteAlerts ?? _checkFavoriteAlerts,
      if (task == Workmanager.iOSBackgroundTask ||
          task == iOSBgProcessingTaskIdentifier)
        'ios_reschedule': rescheduleIOS ?? scheduleIOSProcessingTask,
    };

    Object? firstError;
    StackTrace? firstStackTrace;
    for (final entry in steps.entries) {
      try {
        await entry.value();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
        await CrashReporting.captureException(
          error,
          stackTrace: stackTrace,
          hint: 'background_task.${entry.key}',
          tags: {'task': task, 'step': entry.key},
        );
      }
    }

    if (firstError == null) {
      await BackgroundTaskHealth.recordSuccess();
      return true;
    }
    await BackgroundTaskHealth.recordFailure(
      firstError,
      firstStackTrace ?? StackTrace.empty,
    );
    return false;
  }

  static Future<void> _refreshWidgets() async {
    await WidgetUpdateService.ensureHomeWidgetSetup(strict: true);
    final result = await WidgetUpdateService.refreshAllWidgets();
    if (!result.succeeded) {
      throw WidgetRefreshException(result);
    }
  }

  static Future<void> _checkFavoriteAlerts() async {
    await NotificationService.init();
    await FavoriteResultAlertService.checkForUpdates();
  }

  static bool _iosBgProcessingAvailable = true;

  static Future<void> initializeAndSchedule() async {
    await _ensureInitialized();
    if (Platform.isAndroid) {
      await scheduleAndroidPeriodicTask();
      return;
    }
    if (Platform.isIOS) {
      await scheduleIOSProcessingTask();
    }
  }

  static Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    await Workmanager().initialize(backgroundTaskDispatcher);
    _initialized = true;
  }

  static Future<void> scheduleAndroidPeriodicTask() async {
    await _ensureInitialized();
    await Workmanager().registerPeriodicTask(
      androidPeriodicUniqueName,
      androidPeriodicTaskName,
      frequency: const Duration(minutes: 30),
      initialDelay: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> scheduleIOSProcessingTask() async {
    if (!Platform.isIOS || !_iosBgProcessingAvailable) {
      return;
    }
    await _ensureInitialized();
    try {
      await Workmanager().cancelByUniqueName(iOSBgProcessingTaskIdentifier);
      await Workmanager().registerOneOffTask(
        iOSBgProcessingTaskIdentifier,
        iOSBgProcessingTaskIdentifier,
        initialDelay: const Duration(minutes: 30),
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } on PlatformException catch (error) {
      // BGTaskScheduler can reject requests (e.g. simulator, quotas, disabled capability).
      // Keep background-fetch path alive without crashing startup.
      _iosBgProcessingAvailable = false;
      if (kDebugMode) {
        debugPrint(
          'BackgroundTaskService: iOS BG processing unavailable, '
          'falling back to background fetch only. $error',
        );
      }
    } catch (error) {
      _iosBgProcessingAvailable = false;
      if (kDebugMode) {
        debugPrint(
          'BackgroundTaskService: failed to schedule iOS BG processing task. $error',
        );
      }
    }
  }
}
