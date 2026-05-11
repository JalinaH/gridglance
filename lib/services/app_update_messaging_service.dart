import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

class AppUpdateMessagingService {
  static const String topic = 'app_updates';

  static bool _initialized = false;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;

  static Future<void> init() async {
    if (_initialized) {
      return;
    }
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.subscribeToTopic(topic);
      _foregroundSubscription ??= FirebaseMessaging.onMessage.listen(
        _showForegroundNotification,
      );
      _initialized = true;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('App update messaging init failed: $error');
        debugPrint('$stackTrace');
      }
    }
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title =
        notification?.title ?? message.data['title'] as String? ?? 'GridGlance';
    final body =
        notification?.body ??
        message.data['body'] as String? ??
        'A GridGlance update is available.';
    await NotificationService.showAppUpdateNotification(
      title: title,
      body: body,
    );
  }

  @visibleForTesting
  static void resetForTesting() {
    unawaited(_foregroundSubscription?.cancel());
    _foregroundSubscription = null;
    _initialized = false;
  }
}
