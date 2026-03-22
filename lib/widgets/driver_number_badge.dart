import 'package:flutter/material.dart';

import '../utils/team_colors.dart';

/// A stylized badge showing a driver's permanent number in their team colour.
///
/// Displays the number over a team-colour gradient background with a subtle
/// border and shadow, giving each driver a distinctive visual identity.
class DriverNumberBadge extends StatelessWidget {
  final String number;
  final String teamName;
  final double size;

  const DriverNumberBadge({
    super.key,
    required this.number,
    required this.teamName,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final color = teamColor(teamName);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        number,
        style: TextStyle(
          color: _textColorFor(color),
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          height: 1,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }

  /// Use white text unless the team colour is very light.
  static Color _textColorFor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}
