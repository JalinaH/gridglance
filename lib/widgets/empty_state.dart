import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The kind of empty state to illustrate.
enum EmptyStateType {
  standings,
  race,
  results,
  schedule,
  predictions,
  network,
  generic,
}

/// A polished empty-state illustration that replaces plain "No data" text.
class EmptyState extends StatelessWidget {
  final String message;
  final EmptyStateType type;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.message,
    this.type = EmptyStateType.generic,
    this.iconSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(colors, isDark),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: colors.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(AppColors colors, bool isDark) {
    final iconColor = colors.textMuted.withValues(alpha: 0.5);
    final bgColor = colors.surfaceAlt;

    return Container(
      width: iconSize + 24,
      height: iconSize + 24,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Center(
        child: Icon(_iconData, size: iconSize * 0.6, color: iconColor),
      ),
    );
  }

  IconData get _iconData {
    switch (type) {
      case EmptyStateType.standings:
        return Icons.leaderboard_outlined;
      case EmptyStateType.race:
        return Icons.flag_outlined;
      case EmptyStateType.results:
        return Icons.emoji_events_outlined;
      case EmptyStateType.schedule:
        return Icons.calendar_today_outlined;
      case EmptyStateType.predictions:
        return Icons.psychology_outlined;
      case EmptyStateType.network:
        return Icons.cloud_off_outlined;
      case EmptyStateType.generic:
        return Icons.grid_view_outlined;
    }
  }
}
