import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundTaskHealthSnapshot {
  final int consecutiveFailures;
  final DateTime? lastSuccessAt;
  final DateTime? lastFailureAt;
  final String? lastErrorMessage;

  const BackgroundTaskHealthSnapshot({
    required this.consecutiveFailures,
    required this.lastSuccessAt,
    required this.lastFailureAt,
    required this.lastErrorMessage,
  });

  bool get isStale =>
      consecutiveFailures >= BackgroundTaskHealth.staleFailureThreshold;
}

class BackgroundTaskHealth {
  BackgroundTaskHealth._();

  static const int staleFailureThreshold = 3;

  static const String _keyConsecutiveFailures =
      'background_task.consecutive_failures';
  static const String _keyLastSuccessAt = 'background_task.last_success_at';
  static const String _keyLastFailureAt = 'background_task.last_failure_at';
  static const String _keyLastErrorMessage =
      'background_task.last_error_message';

  static Future<void> recordSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyConsecutiveFailures, 0);
    await prefs.setInt(
      _keyLastSuccessAt,
      DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.remove(_keyLastErrorMessage);
  }

  static Future<void> recordFailure(Object error, StackTrace? stackTrace) async {
    if (kDebugMode) {
      debugPrint('BackgroundTask failure: $error');
      if (stackTrace != null) {
        debugPrint('$stackTrace');
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyConsecutiveFailures) ?? 0;
    await prefs.setInt(_keyConsecutiveFailures, current + 1);
    await prefs.setInt(
      _keyLastFailureAt,
      DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setString(_keyLastErrorMessage, error.toString());
  }

  static Future<BackgroundTaskHealthSnapshot> getSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    return BackgroundTaskHealthSnapshot(
      consecutiveFailures: prefs.getInt(_keyConsecutiveFailures) ?? 0,
      lastSuccessAt: _readDateTime(prefs, _keyLastSuccessAt),
      lastFailureAt: _readDateTime(prefs, _keyLastFailureAt),
      lastErrorMessage: prefs.getString(_keyLastErrorMessage),
    );
  }

  static DateTime? _readDateTime(SharedPreferences prefs, String key) {
    final epoch = prefs.getInt(key);
    if (epoch == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(epoch);
  }
}
