import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';

import 'favorite_result_alert_service.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await NotificationService.init();
      await FavoriteResultAlertService.checkForUpdates();
      if (task == Workmanager.iOSBackgroundTask ||
          task == BackgroundTaskService.iOSBgProcessingTaskIdentifier) {
        await BackgroundTaskService.scheduleIOSProcessingTask();
      }
      return true;
    } catch (_) {
      return false;
    }
  });
}

class BackgroundTaskService {
  static const String androidPeriodicUniqueName =
      'gridglance.favorite_results.periodic';
  static const String androidPeriodicTaskName =
      'gridglance.favorite_results.periodic.task';
  static const String iOSBgProcessingTaskIdentifier =
      'com.example.gridglance.favorite-result-sync';

  static bool _initialized = false;
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
    await Workmanager().initialize(
      backgroundTaskDispatcher,
      isInDebugMode: kDebugMode,
    );
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
      existingWorkPolicy: ExistingWorkPolicy.keep,
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
