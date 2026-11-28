import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import '../utils/circuit_assets.dart';

/// Draws an F1 circuit layout from the maps in `lib/assets/circuits/`, or a
/// placeholder when the circuit has none.
///
/// ### Adding circuit SVGs
/// 1. Save an SVG outline as `lib/assets/circuits/<name>.svg`.
/// 2. Add `<name>` to [CircuitAssets.bundled], plus an alias there if the
///    API's `circuitId` differs from the file name.
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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final trackColor = color ?? colors.f1RedBright;
    final path = CircuitAssets.pathFor(circuitId);
    final placeholder = _CircuitPlaceholder(
      color: trackColor,
      circuitId: circuitId,
    );

    return SizedBox(
      width: width,
      height: height,
      child: path == null
          ? placeholder
          : SvgPicture.asset(
              path,
              width: width,
              height: height,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(trackColor, BlendMode.srcIn),
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
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
