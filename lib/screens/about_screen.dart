import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          "About GridGlance",
          style: TextStyle(
            color: onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: 10),
        Text(
          "GridGlance delivers the latest Formula 1 standings and race schedule "
          "in a fast, glanceable format.",
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        SizedBox(height: 18),
        _buildInfoCard(
          context,
          title: "Data Source",
          value: "Ergast API via jolpi.ca",
        ),
        _buildInfoCard(
          context,
          title: "Season Focus",
          value: "2025 (toggle ready for more seasons)",
        ),
        _buildInfoCard(
          context,
          title: "Made For",
          value: "F1 fans who want the grid at a glance.",
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String value,
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
              color: colors.textMuted,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
