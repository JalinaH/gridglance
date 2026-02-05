import 'package:flutter/material.dart';
import '../models/race.dart';
import '../services/calendar_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_time_format.dart';
import '../widgets/countdown_text.dart';
import '../widgets/f1_scaffold.dart';
import '../widgets/season_cards.dart';

class RaceDetailScreen extends StatelessWidget {
  final Race race;
  final String season;

  const RaceDetailScreen({
    super.key,
    required this.race,
    required this.season,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final raceStart = race.startDateTime;
    return F1Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Next Race"),
            Text(
              "Season $season",
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: 24),
        physics: BouncingScrollPhysics(),
        children: [
          RaceCard(race: race, highlight: true),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(context, "Round", race.round),
                if (raceStart != null)
                  _buildDetailRow(
                    context,
                    "Local time",
                    formatLocalDateTime(context, raceStart),
                  )
                else
                  _buildDetailRow(context, "Date", race.date),
                if (raceStart != null)
                  _buildDetailRowWidget(
                    context,
                    "Countdown",
                    CountdownText(
                      target: raceStart,
                      hideIfPast: false,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                _buildDetailRow(context, "Circuit", race.circuitName),
                _buildDetailRow(context, "Location", race.location),
              ],
            ),
          ),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Session Schedule",
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 10),
                ..._buildSessionRows(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSessionRows(BuildContext context) {
    final sessions = race.sessions
        .where((session) => session.date.isNotEmpty)
        .toList();
    if (sessions.isEmpty) {
      return [
        Text(
          "Session times not available.",
          style: TextStyle(
            color: AppColors.of(context).textMuted,
            fontSize: 12,
          ),
        ),
      ];
    }

    return sessions
        .map(
          (session) => _buildSessionRow(context, session),
        )
        .toList();
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    double labelWidth = 70,
  }) {
    return _buildDetailRowWidget(
      context,
      label,
      Text(
        value,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      labelWidth: labelWidth,
    );
  }

  Widget _buildDetailRowWidget(
    BuildContext context,
    String label,
    Widget value, {
    double labelWidth = 70,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.of(context).textMuted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: value,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionRow(BuildContext context, RaceSession session) {
    final start = session.startDateTime;
    final valueLabel = start == null
        ? session.displayDateTime
        : formatLocalDateTime(context, start);
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              session.name,
              style: TextStyle(
                color: AppColors.of(context).textMuted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valueLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (start != null)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: CountdownText(
                      target: start,
                      hideIfPast: false,
                      style: TextStyle(
                        color: AppColors.of(context).textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (start != null)
            IconButton(
              icon: Icon(Icons.calendar_month, color: AppColors.of(context).textMuted),
              onPressed: () => _addSessionToCalendar(context, session),
            ),
        ],
      ),
    );
  }

  Future<void> _addSessionToCalendar(
    BuildContext context,
    RaceSession session,
  ) async {
    final added = await CalendarService.addSessionToCalendar(
      race: race,
      session: session,
      season: season,
    );
    if (!context.mounted) {
      return;
    }
    final message = added
        ? 'Calendar event ready to add.'
        : 'Session time unavailable.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
