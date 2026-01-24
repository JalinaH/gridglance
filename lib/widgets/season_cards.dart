import 'package:flutter/material.dart';
import '../models/constructor_standing.dart';
import '../models/driver_standing.dart';
import '../models/race.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const GlassCard({
    required this.child,
    this.borderColor,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Ink(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.2)),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: content,
        ),
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  final String text;
  final Color? color;

  const StatPill({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class DriverStandingCard extends StatelessWidget {
  final DriverStanding driver;

  const DriverStandingCard({required this.driver});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Text(
            "#${driver.position}",
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${driver.givenName} ${driver.familyName}",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  driver.teamName,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatPill(
                text: "${driver.points} PTS",
                color: Colors.redAccent.withOpacity(0.8),
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

  const ConstructorStandingCard({required this.team});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Text(
            "#${team.position}",
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.teamName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Constructors",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatPill(
                text: "${team.points} PTS",
                color: Colors.redAccent.withOpacity(0.8),
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

  const RaceCard({required this.race, this.highlight = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: highlight ? Colors.redAccent.withOpacity(0.8) : null,
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
                  race.displayDateTime,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            race.raceName,
            style: TextStyle(
              color: Colors.white,
              fontSize: highlight ? 18 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "${race.circuitName} - ${race.location}",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
