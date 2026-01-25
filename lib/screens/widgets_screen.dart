import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WidgetsScreen extends StatelessWidget {
  const WidgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          "Widgets",
          style: TextStyle(
            color: onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: 10),
        Text(
          "Add your custom components here. This space can showcase "
          "race widgets, custom stats, or experimental UI pieces.",
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        SizedBox(height: 18),
        _buildPlaceholderCard(
          context,
          title: "Race Pace Widget",
          description: "Placeholder for a compact pace comparison module.",
        ),
        _buildPlaceholderCard(
          context,
          title: "Pit Stop Tracker",
          description: "Placeholder for live pit stop insights.",
        ),
        _buildPlaceholderCard(
          context,
          title: "Driver Form",
          description: "Placeholder for recent driver performance.",
        ),
      ],
    );
  }

  Widget _buildPlaceholderCard(
    BuildContext context, {
    required String title,
    required String description,
  }) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
