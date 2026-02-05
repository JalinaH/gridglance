import 'package:flutter/material.dart';
import '../models/constructor_standing.dart';
import '../models/driver_standing.dart';
import '../models/race.dart';
import '../theme/app_theme.dart';
import '../utils/date_time_format.dart';
import 'team_logo.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool showAccent;
  final Color? accentColor;

  const GlassCard({
    super.key,
    required this.child,
    this.borderColor,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.onTap,
    this.showAccent = true,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final border = borderColor ?? colors.border;
    final accent = accentColor ?? colors.f1Red;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadowOpacity = isDark ? 0.35 : 0.12;
    final shadowBlur = isDark ? 18.0 : 12.0;
    final content = Ink(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.surface.withValues(alpha: 0.95),
            colors.surfaceAlt.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: shadowOpacity),
            blurRadius: shadowBlur,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (showAccent)
            Positioned(
              left: 0,
              top: 12,
              bottom: 12,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accent,
                      accent.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );

    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: content,
        ),
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  final String text;
  final Color? color;

  const StatPill({super.key, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final pillGradient = color == null
        ? LinearGradient(
            colors: [
              colors.surfaceAlt,
              colors.surface,
            ],
          )
        : LinearGradient(
            colors: [
              color!,
              color!.withValues(alpha: 0.75),
            ],
          );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: pillGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color == null ? onSurface : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class DriverStandingCard extends StatelessWidget {
  final DriverStanding driver;
  final VoidCallback? onTap;

  const DriverStandingCard({
    super.key,
    required this.driver,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Text(
            "#${driver.position}",
            style: TextStyle(
              color: colors.f1RedBright,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(width: 12),
          TeamLogo(teamName: driver.teamName, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${driver.givenName} ${driver.familyName}",
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  driver.teamName,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatPill(
                text: "${driver.points} PTS",
                color: colors.f1Red,
              ),
              SizedBox(height: 6),
              StatPill(text: "${driver.wins} W"),
            ],
          ),
        ],
      ),
    );
  }
}

class ConstructorStandingCard extends StatelessWidget {
  final ConstructorStanding team;
  final VoidCallback? onTap;

  const ConstructorStandingCard({
    super.key,
    required this.team,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Text(
            "#${team.position}",
            style: TextStyle(
              color: colors.f1RedBright,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(width: 12),
          TeamLogo(teamName: team.teamName, size: 30),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.teamName,
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Constructors",
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatPill(
                text: "${team.points} PTS",
                color: colors.f1Red,
              ),
              SizedBox(height: 6),
              StatPill(text: "${team.wins} W"),
            ],
          ),
        ],
      ),
    );
  }
}

class RaceCard extends StatelessWidget {
  final Race race;
  final bool highlight;
  final VoidCallback? onTap;

  const RaceCard({
    super.key,
    required this.race,
    this.highlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final start = race.startDateTime;
    final dateLabel = start == null
        ? race.date
        : (race.time == null || race.time!.isEmpty)
            ? formatLocalDate(context, start)
            : formatLocalDateTime(context, start);
    return GlassCard(
      borderColor: highlight
          ? colors.f1Red.withValues(alpha: 0.6)
          : null,
      accentColor: highlight ? colors.f1Red : colors.f1RedBright,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatPill(text: "Round ${race.round}"),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  dateLabel,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            race.raceName,
            style: TextStyle(
              color: onSurface,
              fontSize: highlight ? 18 : 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "${race.circuitName} - ${race.location}",
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
