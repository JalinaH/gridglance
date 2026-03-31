import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/f1_image_service.dart';
import '../theme/app_theme.dart';
import '../utils/team_colors.dart';

/// Displays a team car / livery image.
///
/// ### Image sources
/// - **Network URL**: pass [imageUrl] to load from a CDN.
/// - **Fallback**: shows the team logo from existing assets, or a car icon
///   over a team-colour gradient.
class CarImage extends StatelessWidget {
  final String teamName;
  final String constructorId;
  final String? imageUrl;
  final double width;
  final double height;

  const CarImage({
    super.key,
    required this.teamName,
    required this.constructorId,
    this.imageUrl,
    this.width = 120,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    final color = teamColor(teamName);
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: isDark ? 0.15 : 0.1),
            color.withValues(alpha: isDark ? 0.05 : 0.03),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: _buildImage(color, colors),
      ),
    );
  }

  String? get _resolvedUrl {
    if (imageUrl != null && imageUrl!.isNotEmpty) return imageUrl;
    return F1ImageService.instance.carImageUrl(constructorId);
  }

  Widget _buildImage(Color color, AppColors colors) {
    final url = _resolvedUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: BoxFit.contain,
        placeholder: (_, _) => _placeholder(color),
        errorWidget: (_, _, _) => _placeholder(color),
      );
    }
    return _placeholder(color);
  }

  Widget _placeholder(Color color) {
    return Center(
      child: Icon(
        Icons.directions_car_rounded,
        color: color.withValues(alpha: 0.4),
        size: height * 0.5,
      ),
    );
  }
}
