import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Fetches and caches driver headshot URLs from the OpenF1 API
/// and provides car image URLs from official F1 media.
///
/// Call [init] once at startup; after that, use the sync lookup
/// methods [driverHeadshotUrl] and [carImageUrl].
class F1ImageService {
  F1ImageService._();
  static final instance = F1ImageService._();

  static const _openF1Url =
      'https://api.openf1.org/v1/drivers?session_key=latest';
  static const _cacheKey = 'f1_image_service_v1';
  static const _cacheTtl = Duration(hours: 24);

  /// driver_number (as String) → headshot URL
  final Map<String, String> _byNumber = {};

  /// name_acronym (uppercase, e.g. "VER") → headshot URL
  final Map<String, String> _byCode = {};

  bool _initialized = false;

  /// Loads driver image data. Safe to call multiple times.
  ///
  /// Cached data is always used, however old: a day-old headshot beats no
  /// headshot when the network is down. Only a first launch with nothing
  /// cached waits for the network; a stale cache refreshes in the background.
  Future<void> init() async {
    if (_initialized) return;
    final cache = await _loadFromCache();
    if (cache == _CacheState.missing) {
      await _fetchFromApi();
    } else if (cache == _CacheState.stale) {
      unawaited(_fetchFromApi());
    }
    _initialized = true;
  }

  @visibleForTesting
  void resetForTesting() {
    _byNumber.clear();
    _byCode.clear();
    _initialized = false;
  }

  /// Returns a headshot URL for a driver, matched by permanent number or code.
  /// Returns `null` if no match is found.
  String? driverHeadshotUrl({String? permanentNumber, String? code}) {
    if (permanentNumber != null && _byNumber.containsKey(permanentNumber)) {
      return _byNumber[permanentNumber];
    }
    if (code != null && _byCode.containsKey(code.toUpperCase())) {
      return _byCode[code.toUpperCase()];
    }
    return null;
  }

  /// Season whose car artwork [carImageUrl] points at. F1 publishes new
  /// artwork (and new path slugs) each season, so bump this together with
  /// [_carSlugs] when the next season's images go live.
  static const int carImageSeason = 2026;

  /// Returns a car image URL for a constructor using official F1 media.
  ///
  /// Requests PNG explicitly (`f_png`): the source is WebP, but the native
  /// home screen widgets decode these bytes directly. Unknown or missing
  /// cars resolve to F1's generic fallback car rather than a 404.
  String? carImageUrl(String constructorId) {
    final slug = _carSlugs[constructorId];
    if (slug == null) return null;
    const season = carImageSeason;
    return 'https://media.formula1.com/image/upload/c_lfill,h_224/f_png'
        '/d_common:f1:$season:fallback:car:${season}fallbackcarright.webp'
        '/common/f1/$season/$slug/$season${slug}carright.webp';
  }

  // ─── Private ───────────────────────────────────────────────

  Future<void> _fetchFromApi() async {
    try {
      final response = await http
          .get(Uri.parse(_openF1Url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final drivers = jsonDecode(response.body) as List;
      final byNumber = <String, String>{};
      final byCode = <String, String>{};

      for (final d in drivers) {
        final driver = d as Map<String, dynamic>;
        final url = driver['headshot_url'] as String?;
        if (url == null || url.isEmpty) continue;

        final number = driver['driver_number'];
        if (number != null) {
          byNumber[number.toString()] = url;
        }

        final acronym = driver['name_acronym'] as String?;
        if (acronym != null) {
          byCode[acronym.toUpperCase()] = url;
        }
      }

      // An empty or headshot-less response must not wipe what we have.
      if (byNumber.isEmpty && byCode.isEmpty) return;
      _byNumber
        ..clear()
        ..addAll(byNumber);
      _byCode
        ..clear()
        ..addAll(byCode);

      await _writeCache();
    } catch (_) {
      // Silently fail — cached data or fallback initials will be used.
    }
  }

  Future<_CacheState> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return _CacheState.missing;

      final cached = jsonDecode(raw) as Map<String, dynamic>;
      final byNumber = (cached['by_number'] as Map<String, dynamic>?) ?? {};
      final byCode = (cached['by_code'] as Map<String, dynamic>?) ?? {};

      _byNumber
        ..clear()
        ..addAll(byNumber.cast<String, String>());
      _byCode
        ..clear()
        ..addAll(byCode.cast<String, String>());
      if (_byNumber.isEmpty && _byCode.isEmpty) return _CacheState.missing;

      final savedAt = DateTime.tryParse(cached['saved_at'] as String? ?? '');
      final expired =
          savedAt == null || DateTime.now().difference(savedAt) > _cacheTtl;
      return expired ? _CacheState.stale : _CacheState.fresh;
    } catch (_) {
      // Corrupted cache — treat as absent.
      _byNumber.clear();
      _byCode.clear();
      return _CacheState.missing;
    }
  }

  Future<void> _writeCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode({
        'saved_at': DateTime.now().toIso8601String(),
        'by_number': _byNumber,
        'by_code': _byCode,
      }),
    );
  }

  /// Maps Ergast constructor IDs to the F1 media URL slug.
  /// Jolpica constructorId -> F1 media slug for [carImageSeason].
  static const Map<String, String> _carSlugs = {
    'red_bull': 'redbullracing',
    'ferrari': 'ferrari',
    'mercedes': 'mercedes',
    'mclaren': 'mclaren',
    'aston_martin': 'astonmartin',
    'alpine': 'alpine',
    'haas': 'haasf1team',
    'rb': 'racingbulls',
    'williams': 'williams',
    'audi': 'audi',
    // Sauber became Audi for 2026; keep older seasons showing a car.
    'sauber': 'audi',
    'cadillac': 'cadillac',
  };
}

enum _CacheState { missing, stale, fresh }
