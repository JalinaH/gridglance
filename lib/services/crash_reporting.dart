import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Thin wrapper around Sentry. The wrapper exists so:
/// - Call sites import this service, not the SDK directly — easier to swap
///   backends or add additional sinks later.
/// - When the DSN is empty (dev builds without `secrets.json`), every
///   method is a no-op instead of crashing on a missing init.
///
/// The DSN is provided at build time via `--dart-define-from-file`. See
/// CLAUDE.md for the run/build invocation.
class CrashReporting {
  CrashReporting._();

  static const String _dsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  static bool get isEnabled => _dsn.isNotEmpty;

  /// Initializes Sentry and runs [appRunner] inside its zone so unhandled
  /// async errors are captured automatically.
  ///
  /// When the DSN is empty, [appRunner] still runs — initialization is just
  /// skipped. This keeps dev builds working without any configuration.
  static Future<void> runWithCrashReporting(
    Future<void> Function() appRunner,
  ) async {
    if (!isEnabled) {
      await appRunner();
      return;
    }
    await SentryFlutter.init((options) {
      options.dsn = _dsn;
      // 100% of errors, 10% of performance traces.
      options.tracesSampleRate = 0.1;
      // Don't attach user PII — the app has no logins; any "user"
      // breadcrumbs would just be device IDs which we already get from
      // Sentry's default device context.
      options.sendDefaultPii = false;
      // Skip Sentry in debug to keep the dashboard clean — local dev
      // crashes show up in the console anyway.
      options.environment = kDebugMode ? 'debug' : 'production';
      options.beforeSend = (event, hint) {
        if (kDebugMode) return null;
        return event;
      };
    }, appRunner: appRunner);
  }

  /// Reports a caught exception with optional context tags.
  static Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
    String? hint,
    Map<String, String>? tags,
  }) async {
    if (!isEnabled) return;
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: hint == null ? null : Hint.withMap({'context': hint}),
      withScope: tags == null
          ? null
          : (scope) {
              for (final entry in tags.entries) {
                scope.setTag(entry.key, entry.value);
              }
            },
    );
  }
}
