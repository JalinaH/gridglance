import 'dart:convert';

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

  /// Pre-fetches driver image data. Safe to call multiple times.
  Future<void> init() async {
    if (_initialized) return;
    await _loadFromCache();
    if (_byNumber.isEmpty) {
      await _fetchFromApi();
    } else {
      // Refresh in background if cache exists but may be stale.
      _fetchFromApi();
    }
    _initialized = true;
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

  /// Returns a car image URL for a constructor using official F1 media.
  String? carImageUrl(String constructorId) {
    final slug = _constructorSlug(constructorId);
    if (slug == null) return null;
    return 'https://media.formula1.com/d_team_car_fallback_image.png'
        '/content/dam/fom-website/teams/2025/$slug.png';
  }

  // ─── Private ───────────────────────────────────────────────

  Future<void> _fetchFromApi() async {
    try {
      final response = await http.get(Uri.parse(_openF1Url));
      if (response.statusCode != 200) return;

      final drivers = jsonDecode(response.body) as List;
      _byNumber.clear();
      _byCode.clear();

      for (final d in drivers) {
        final driver = d as Map<String, dynamic>;
        final url = driver['headshot_url'] as String?;
        if (url == null || url.isEmpty) continue;

        final number = driver['driver_number'];
        if (number != null) {
          _byNumber[number.toString()] = url;
        }

        final acronym = driver['name_acronym'] as String?;
        if (acronym != null) {
          _byCode[acronym.toUpperCase()] = url;
        }
      }

      await _writeCache();
    } catch (_) {
      // Silently fail — cached data or fallback initials will be used.
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;

      final cached = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(cached['saved_at'] as String? ?? '');
      if (savedAt != null && DateTime.now().difference(savedAt) > _cacheTtl) {
        return; // Cache expired — will fetch fresh data.
      }

      final byNumber = (cached['by_number'] as Map<String, dynamic>?) ?? {};
      final byCode = (cached['by_code'] as Map<String, dynamic>?) ?? {};

      _byNumber
        ..clear()
        ..addAll(byNumber.cast<String, String>());
      _byCode
        ..clear()
        ..addAll(byCode.cast<String, String>());
    } catch (_) {
      // Corrupted cache — ignore.
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
  static String? _constructorSlug(String constructorId) {
    const mapping = {
      'red_bull': 'red-bull-racing',
      'ferrari': 'ferrari',
      'mercedes': 'mercedes',
      'mclaren': 'mclaren',
      'aston_martin': 'aston-martin',
      'alpine': 'alpine',
      'haas': 'haas',
      'rb': 'racing-bulls',
      'williams': 'williams',
      'sauber': 'kick-sauber',
      'cadillac': 'cadillac',
    };
    return mapping[constructorId];
  }
}
