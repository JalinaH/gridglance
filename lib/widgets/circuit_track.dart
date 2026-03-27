import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// Draws an F1 circuit layout.
///
/// Tries to load an SVG from `lib/assets/circuits/{circuitId}.svg` first.
/// If no SVG asset exists, shows a placeholder icon.
///
/// ### Adding circuit SVGs
/// 1. Download or trace an SVG outline of the circuit (see ASSET_GUIDE.md).
/// 2. Save it as `lib/assets/circuits/{circuitId}.svg`
///    (e.g. `monaco.svg`, `silverstone.svg`).
/// 3. The widget picks it up automatically — no code changes needed.
class CircuitTrack extends StatelessWidget {
  final String circuitId;
  final double width;
  final double height;
  final Color? color;

  const CircuitTrack({
    super.key,
    required this.circuitId,
    this.width = 120,
    this.height = 80,
    this.color,
  });

  String get _assetPath => 'lib/assets/circuits/$circuitId.svg';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final trackColor = color ?? colors.f1RedBright;

    return SizedBox(
      width: width,
      height: height,
      child: FutureBuilder<bool>(
        future: _assetExists(_assetPath),
        builder: (context, snapshot) {
          if (snapshot.data == true) {
            return SvgPicture.asset(
              _assetPath,
              width: width,
              height: height,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(trackColor, BlendMode.srcIn),
            );
          }
          // Placeholder when no SVG exists yet.
          return _CircuitPlaceholder(color: trackColor, circuitId: circuitId);
        },
      ),
    );
  }

  static final Map<String, bool> _cache = {};

  static Future<bool> _assetExists(String path) async {
    if (_cache.containsKey(path)) return _cache[path]!;
    try {
      await rootBundle.load(path);
      _cache[path] = true;
      return true;
    } catch (_) {
      _cache[path] = false;
      return false;
    }
  }
}

/// Minimal placeholder showing a track icon with the circuit name initial.
class _CircuitPlaceholder extends StatelessWidget {
  final Color color;
  final String circuitId;

  const _CircuitPlaceholder({required this.color, required this.circuitId});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Icon(
          Icons.route_rounded,
          color: color.withValues(alpha: 0.4),
          size: 24,
        ),
      ),
    );
  }
}
