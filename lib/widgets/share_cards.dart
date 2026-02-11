import 'package:flutter/material.dart';

import '../models/constructor_standing.dart';
import '../models/driver_standing.dart';
import '../models/race.dart';
import '../theme/app_theme.dart';
import '../utils/date_time_format.dart';
import 'countdown_text.dart';

class DriverStandingsShareCard extends StatelessWidget {
  final List<DriverStanding> standings;
  final String season;

  const DriverStandingsShareCard({
    super.key,
    required this.standings,
    required this.season,
  });

  @override
  Widget build(BuildContext context) {
    final top = standings.take(5).toList();
    return _ShareFrame(
      title: 'Driver Standings',
      subtitle: 'Season $season',
      child: Column(
        children: top
            .map(
              (driver) => _standingRow(
                context: context,
                position: driver.position,
                name: '${driver.givenName} ${driver.familyName}',
                meta: driver.teamName,
                points: '${driver.points} pts',
              ),
            )
            .toList(),
      ),
    );
  }
}

class ConstructorStandingsShareCard extends StatelessWidget {
  final List<ConstructorStanding> standings;
  final String season;

  const ConstructorStandingsShareCard({
    super.key,
    required this.standings,
    required this.season,
  });

  @override
  Widget build(BuildContext context) {
    final top = standings.take(5).toList();
    return _ShareFrame(
      title: 'Team Standings',
      subtitle: 'Season $season',
      child: Column(
        children: top
            .map(
              (team) => _standingRow(
                context: context,
                position: team.position,
                name: team.teamName,
                meta: '${team.wins} wins',
                points: '${team.points} pts',
              ),
            )
            .toList(),
      ),
    );
  }
}

class RaceCountdownShareCard extends StatelessWidget {
  final Race race;
  final String season;

  const RaceCountdownShareCard({
    super.key,
    required this.race,
    required this.season,
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
    return _ShareFrame(
      title: 'Race Countdown',
      subtitle: 'Season $season',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            race.raceName,
            style: TextStyle(
              color: onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '${race.circuitName} • ${race.location}',
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
          SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceAlt.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel,
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (start != null)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: CountdownText(
                      target: start,
                      hideIfPast: false,
                      refreshInterval: Duration(minutes: 1),
                      style: TextStyle(
                        color: colors.f1RedBright,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ShareFrame({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.surface, colors.surfaceAlt],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                'GridGlance',
                style: TextStyle(
                  color: colors.f1RedBright,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

Widget _standingRow({
  required BuildContext context,
  required String position,
  required String name,
  required String meta,
  required String points,
}) {
  final colors = AppColors.of(context);
  final onSurface = Theme.of(context).colorScheme.onSurface;
  return Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceAlt.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.85)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              'P$position',
              style: TextStyle(
                color: colors.f1RedBright,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  meta,
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            points,
            style: TextStyle(
              color: onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}
