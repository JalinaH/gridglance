import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Bounded disk cache for `CachedNetworkImage`. Without this, the default
/// `DefaultCacheManager` keeps every fetched image forever — driver photos,
/// car renders, and team logos can grow unbounded over weeks of use.
class GridGlanceImageCache {
  GridGlanceImageCache._();

  static const String _key = 'gridglance_image_cache';

  static final CacheManager instance = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
    ),
  );
}
