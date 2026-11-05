import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      final response = await httpClient
          .get(configUri ?? defaultConfigUri)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
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
