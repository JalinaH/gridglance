import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crash_reporting.dart';

class AppUpdateNotice {
  final int latestBuild;
  final String latestVersion;
  final String releaseNotes;
  final Uri storeUrl;

  const AppUpdateNotice({
    required this.latestBuild,
    required this.latestVersion,
    required this.releaseNotes,
    required this.storeUrl,
  });
}

class AppUpdateService {
  static final Uri defaultConfigUri = Uri.parse(
    'https://jalinah.github.io/gridglance-web/update.json',
  );
  static final Uri defaultStoreUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.gridglance.app',
  );
  static const String _dismissedBuildKey = 'dismissed_app_update_build';

  /// Called when the hosted config is missing or unreadable. That is a
  /// publishing mistake, not a network blip, and it silently disables update
  /// prompts for every user, so it must be visible somewhere.
  @visibleForTesting
  static void Function(String reason, Uri uri) configProblemReporter =
      _reportConfigProblemToSentry;

  static bool _configProblemReported = false;

  @visibleForTesting
  static void resetForTesting() {
    configProblemReporter = _reportConfigProblemToSentry;
    _configProblemReported = false;
  }

  /// Reports at most once per app run: the check repeats on every resume and
  /// one event is enough to raise the alarm.
  static void _reportConfigProblem(String reason, Uri uri) {
    if (_configProblemReported) return;
    _configProblemReported = true;
    configProblemReporter(reason, uri);
  }

  static void _reportConfigProblemToSentry(String reason, Uri uri) {
    if (kDebugMode) {
      debugPrint('AppUpdateService: update config problem ($reason) at $uri');
    }
    unawaited(
      CrashReporting.captureException(
        StateError('App update config unavailable: $reason'),
        stackTrace: StackTrace.current,
        hint: 'app_update.config',
        tags: {'reason': reason},
      ),
    );
  }

  Future<AppUpdateNotice?> checkForUpdate({
    http.Client? client,
    SharedPreferences? preferences,
    String? installedBuildNumber,
    Uri? configUri,
    String? platform,
  }) async {
    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    try {
      final uri = configUri ?? defaultConfigUri;
      final response = await httpClient
          .get(uri)
          .timeout(const Duration(seconds: 4));
      final status = response.statusCode;
      if (status < 200 || status >= 300) {
        // 4xx means the file is missing or moved. 5xx is the host having a
        // bad moment and will pass on its own.
        if (status >= 400 && status < 500) {
          _reportConfigProblem('http-$status', uri);
        }
        return null;
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        _reportConfigProblem('invalid-json', uri);
        return null;
      }
      if (decoded is! Map<String, dynamic>) {
        _reportConfigProblem('invalid-json', uri);
        return null;
      }
      final notice = _noticeFromJson(
        decoded,
        platform ?? (Platform.isIOS ? 'ios' : 'android'),
      );
      if (notice == null) {
        return null;
      }

      final installedBuild = await _installedBuild(installedBuildNumber);
      if (notice.latestBuild <= installedBuild) {
        return null;
      }

      final prefs = preferences ?? await SharedPreferences.getInstance();
      if (prefs.getInt(_dismissedBuildKey) == notice.latestBuild) {
        return null;
      }
      return notice;
    } catch (_) {
      return null;
    } finally {
      if (ownsClient) {
        httpClient.close();
      }
    }
  }

  Future<void> dismiss(AppUpdateNotice notice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dismissedBuildKey, notice.latestBuild);
  }

  /// Reads the update block for [platform] (`android` or `ios`).
  ///
  /// Android also accepts the legacy flat format (fields at the top level)
  /// and falls back to the Play Store link. iOS needs its own block with an
  /// explicit `storeUrl`, so iOS users are never sent to the Play Store.
  AppUpdateNotice? _noticeFromJson(Map<String, dynamic> json, String platform) {
    final isAndroid = platform == 'android';
    final platformJson = json[platform];
    final Map<String, dynamic>? source = platformJson is Map<String, dynamic>
        ? platformJson
        : (isAndroid ? json : null);
    if (source == null) {
      return null;
    }
    final latestBuild = _readInt(source['latestBuild']);
    if (latestBuild == null) {
      return null;
    }
    final latestVersion = _readString(source['latestVersion']) ?? '';
    final releaseNotes =
        _readString(source['releaseNotes']) ??
        'A newer version of GridGlance is available.';
    final storeUrlValue = _readString(source['storeUrl']);
    final parsedStoreUrl = storeUrlValue == null
        ? null
        : Uri.tryParse(storeUrlValue);
    final storeUrl = parsedStoreUrl ?? (isAndroid ? defaultStoreUri : null);
    if (storeUrl == null) {
      return null;
    }
    return AppUpdateNotice(
      latestBuild: latestBuild,
      latestVersion: latestVersion,
      releaseNotes: releaseNotes,
      storeUrl: storeUrl,
    );
  }

  Future<int> _installedBuild(String? installedBuildNumber) async {
    final buildNumber =
        installedBuildNumber ?? (await PackageInfo.fromPlatform()).buildNumber;
    return int.tryParse(buildNumber) ?? 0;
  }

  int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  String? _readString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }
}
