import 'dart:convert';

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
      final notice = _noticeFromJson(decoded);
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

  AppUpdateNotice? _noticeFromJson(Map<String, dynamic> json) {
    final platformJson = json['android'];
    final source = platformJson is Map<String, dynamic> ? platformJson : json;
    final latestBuild = _readInt(source['latestBuild']);
    if (latestBuild == null) {
      return null;
    }
    final latestVersion = _readString(source['latestVersion']) ?? '';
    final releaseNotes =
        _readString(source['releaseNotes']) ??
        'A newer version of GridGlance is available.';
    final storeUrlValue = _readString(source['storeUrl']);
    final storeUrl = storeUrlValue == null ? null : Uri.tryParse(storeUrlValue);
    return AppUpdateNotice(
      latestBuild: latestBuild,
      latestVersion: latestVersion,
      releaseNotes: releaseNotes,
      storeUrl: storeUrl ?? defaultStoreUri,
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
