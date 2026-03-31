import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/f1_image_service.dart';
import '../theme/app_theme.dart';
import '../utils/team_colors.dart';

/// Displays a driver headshot with a team-colour accent ring.
///
/// ### Image sources (choose one)
/// - **Auto-resolve**: if [permanentNumber] or [code] is provided the widget
///   looks up the headshot URL from [F1ImageService] automatically.
/// - **Network URL**: pass [imageUrl] to load from a CDN / API.
/// - **Local asset**: place PNGs in `lib/assets/drivers/{driverId}.png`
///   and pass [driverId] only — the widget loads the asset automatically.
/// - **Fallback**: if none of the above resolve the widget shows the driver's
///   initials over a team-colour gradient.
class DriverPhoto extends StatelessWidget {
  final String driverId;
  final String? imageUrl;
  final String? permanentNumber;
  final String? code;
  final String teamName;
  final String initials;
  final double size;

  const DriverPhoto({
    super.key,
    required this.driverId,
    this.imageUrl,
    this.permanentNumber,
    this.code,
    required this.teamName,
    required this.initials,
    this.size = 48,
  });

  String get _assetPath => 'lib/assets/drivers/$driverId.png';

  @override
  Widget build(BuildContext context) {
    final color = teamColor(teamName);
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.8), color.withValues(alpha: 0.4)],
        ),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.6 : 0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(child: _buildImage(colors, color)),
    );
  }

  String? get _resolvedUrl {
    if (imageUrl != null && imageUrl!.isNotEmpty) return imageUrl;
    return F1ImageService.instance.driverHeadshotUrl(
      permanentNumber: permanentNumber,
      code: code,
    );
  }

  Widget _buildImage(AppColors colors, Color color) {
    final url = _resolvedUrl;
    // 1. Try network URL (explicit or auto-resolved from F1ImageService).
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => _initialsPlaceholder(color),
        errorWidget: (_, _, _) => _tryAsset(color),
      );
    }

    // 2. Try local asset.
    return _tryAsset(color);
  }

  Widget _tryAsset(Color color) {
    return Image.asset(
      _assetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _initialsPlaceholder(color),
    );
  }

  Widget _initialsPlaceholder(Color color) {
    return Container(
      color: Colors.transparent,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: _textColorFor(color),
          fontSize: size * 0.35,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  static Color _textColorFor(Color bg) {
    return bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }
}
