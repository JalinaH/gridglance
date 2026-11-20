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
    // Car images never block launch: the stored season is enough to start.
    unawaited(_resolveCarImageSeason());
    _initialized = true;
  }

  @visibleForTesting
  void resetForTesting() {
    _byNumber.clear();
    _byCode.clear();
    _initialized = false;
    _carImageSeason = baselineCarImageSeason;
    clock = DateTime.now;
  }

  /// Runs the season probe directly so tests can await it.
  @visibleForTesting
  Future<void> resolveCarImageSeasonForTesting() => _resolveCarImageSeason();

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

  /// Newest season whose car artwork is known to exist. Used until a probe
  /// finds a newer one, and as the floor for every probe.
  static const int baselineCarImageSeason = 2026;

  /// F1's generic fallback car from [baselineCarImageSeason]. It always
  /// exists, unlike a season's own fallback, which is a blank image until
  /// that season's artwork is published.
  static const String _fallbackCar =
      'd_common:f1:$baselineCarImageSeason:fallback:car:'
      '${baselineCarImageSeason}fallbackcarright.webp';

  static const _carSeasonKey = 'f1_image_service_car_season_v1';
  static const _carSeasonCheckedAtKey =
      'f1_image_service_car_season_checked_at_v1';
  static const _carSeasonCheckInterval = Duration(hours: 24);

  /// Team used to probe whether a season's artwork is published.
  static const _probeSlug = 'ferrari';

  /// Clock indirection so tests can simulate a new year.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  int _carImageSeason = baselineCarImageSeason;

  /// Season whose car artwork [carImageUrl] currently points at.
  int get carImageSeason => _carImageSeason;

  /// Returns a car image URL for a constructor using official F1 media.
  ///
  /// Requests PNG explicitly (`f_png`): the source is WebP, but the native
  /// home screen widgets decode these bytes directly. A car missing for the
  /// season resolves to F1's generic fallback car rather than a 404.
  String? carImageUrl(String constructorId) {
    final slug = _carSlugs[constructorId];
    if (slug == null) return null;
    final season = _carImageSeason;
    return 'https://media.formula1.com/image/upload/c_lfill,h_224/f_png'
        '/$_fallbackCar'
        '/common/f1/$season/$slug/$season${slug}carright.webp';
  }

  /// Points [carImageUrl] at the newest season with published artwork.
  ///
  /// F1 publishes each season's cars at launch, usually in February. Until
  /// then the new season's paths are missing, so the newest season that
  /// answers is used. Checked at most once a day; a failed check keeps the
  /// last known season.
  Future<void> _resolveCarImageSeason() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(_carSeasonKey);
      if (stored != null && stored >= baselineCarImageSeason) {
        _carImageSeason = stored;
      }
      final now = clock();
      final checkedAtMs = prefs.getInt(_carSeasonCheckedAtKey);
      if (checkedAtMs != null &&
          now.difference(DateTime.fromMillisecondsSinceEpoch(checkedAtMs)) <
              _carSeasonCheckInterval) {
        return;
      }

      for (var year = now.year; year > _carImageSeason; year--) {
        final published = await _isCarSeasonPublished(year);
        if (published == null) return; // Network trouble: try again later.
        if (published) {
          _carImageSeason = year;
          break;
        }
      }
      await prefs.setInt(_carSeasonKey, _carImageSeason);
      await prefs.setInt(_carSeasonCheckedAtKey, now.millisecondsSinceEpoch);
    } catch (_) {
      // Keep whatever season we had; car images still resolve.
    }
  }

  /// Whether [year]'s car artwork exists, or null if we could not tell.
  Future<bool?> _isCarSeasonPublished(int year) async {
    try {
      // A tiny rendition: we only need the status code.
      final response = await http
          .head(
            Uri.parse(
              'https://media.formula1.com/image/upload/h_8/common/f1/$year/'
              '$_probeSlug/$year${_probeSlug}carright.webp',
            ),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) return true;
      if (response.statusCode == 404) return false;
      return null;
    } catch (_) {
      return null;
    }
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
  /// Jolpica constructorId -> F1 media slug. If a team's slug changes in a
  /// new season, its car shows F1's generic fallback until this is updated.
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
