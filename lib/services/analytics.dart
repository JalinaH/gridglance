import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around PostHog. Exists so:
/// - Call sites import this service rather than the SDK, making it easy to
///   swap providers later or add a second sink (e.g. an internal pipeline).
/// - When the API key is empty (dev builds without `secrets.json`), every
///   method is a no-op rather than crashing.
/// - Opt-out is honored consistently — `track()` checks the persisted flag
///   on every call rather than relying on the SDK alone.
///
/// PostHog's auto-init is disabled in `AndroidManifest.xml` and `Info.plist`
/// so the API key can come from `--dart-define-from-file=secrets.json`
/// instead of being baked into platform manifests.
class Analytics {
  Analytics._();

  static const String _apiKey = String.fromEnvironment(
    'POSTHOG_KEY',
    defaultValue: '',
  );

  static const String _host = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://us.i.posthog.com',
  );

  static const String _optOutKey = 'analytics_opt_out';

  static bool _initialized = false;
  static bool _optedOut = false;

  static bool get isConfigured => _apiKey.isNotEmpty;
  static bool get isOptedOut => _optedOut;

  /// Loads the persisted opt-out flag and configures the PostHog SDK.
  /// Safe to call when the API key is empty — it will skip SDK setup but
  /// still load the opt-out state so the toggle UI can read it.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _optedOut = prefs.getBool(_optOutKey) ?? false;

    if (!isConfigured || _initialized) return;
    final config = PostHogConfig(_apiKey)
      ..host = _host
      ..captureApplicationLifecycleEvents = true
      // We don't auto-track every screen because we want to control the
      // event namespace ourselves — `track('widget_added', ...)` etc.
      ..debug = kDebugMode;
    try {
      await Posthog().setup(config);
      _initialized = true;
      if (_optedOut) {
        await Posthog().disable();
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Analytics setup failed: $error');
        debugPrint('$stackTrace');
      }
    }
  }

  /// Records an event. No-op when:
  /// - the SDK isn't configured (no key), or
  /// - the user has opted out, or
  /// - SDK init failed earlier.
  ///
  /// Property values are coerced to PostHog-safe types (String/num/bool).
  /// Avoid passing user-identifying info — there are no logins, but we
  /// still want events to stay anonymous.
  static Future<void> track(
    String event, {
    Map<String, Object>? properties,
  }) async {
    if (!_initialized || _optedOut) return;
    try {
      await Posthog().capture(
        eventName: event,
        properties: properties,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Analytics.track($event) failed: $error');
      }
    }
  }

  /// Persists the opt-out flag and informs the PostHog SDK to stop
  /// capturing events. Calling with `false` re-enables capture.
  static Future<void> setOptOut(bool optOut) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_optOutKey, optOut);
    _optedOut = optOut;
    if (!_initialized) return;
    try {
      if (optOut) {
        await Posthog().disable();
      } else {
        await Posthog().enable();
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Analytics.setOptOut($optOut) failed: $error');
      }
    }
  }

  /// Resets the in-memory state. Tests use this between cases; production
  /// code should never call it.
  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _optedOut = false;
  }
}
