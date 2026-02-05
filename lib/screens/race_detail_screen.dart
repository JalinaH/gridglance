import 'package:flutter/material.dart';
import '../models/race.dart';
import '../services/calendar_service.dart';
import '../services/notification_preferences.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_time_format.dart';
import '../widgets/countdown_text.dart';
import '../widgets/f1_scaffold.dart';
import '../widgets/season_cards.dart';

class RaceDetailScreen extends StatefulWidget {
  final Race race;
  final String season;

  const RaceDetailScreen({
    super.key,
    required this.race,
    required this.season,
  });

  @override
  State<RaceDetailScreen> createState() => _RaceDetailScreenState();
}

class _RaceDetailScreenState extends State<RaceDetailScreen> {
  static const Duration _leadTime = Duration(minutes: 15);
  final Map<String, bool> _notifyEnabled = {};

  @override
  void initState() {
    super.initState();
    _loadNotificationState();
  }

  Future<void> _loadNotificationState() async {
    final sessions = widget.race.sessions;
    for (final session in sessions) {
      final enabled = await NotificationPreferences.isSessionEnabled(
        race: widget.race,
        session: session,
        season: widget.season,
      );
      _notifyEnabled[_sessionKey(session)] = enabled;
    }
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  String _sessionKey(RaceSession session) {
    return NotificationService.sessionKey(
      race: widget.race,
      session: session,
      season: widget.season,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final raceStart = widget.race.startDateTime;
    return F1Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Next Race"),
            Text(
              "Season ${widget.season}",
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: 24),
        physics: BouncingScrollPhysics(),
        children: [
          RaceCard(race: widget.race, highlight: true),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(context, "Round", widget.race.round),
                if (raceStart != null)
                  _buildDetailRow(
                    context,
                    "Local time",
                    formatLocalDateTime(context, raceStart),
                  )
                else
                  _buildDetailRow(context, "Date", widget.race.date),
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
                _buildDetailRow(context, "Circuit", widget.race.circuitName),
                _buildDetailRow(context, "Location", widget.race.location),
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
    final sessions = widget.race.sessions
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
    final hasTime = session.time != null && session.time!.isNotEmpty;
    final valueLabel = start == null
        ? session.displayDateTime
        : formatLocalDateTime(context, start);
    final notifyKey = _sessionKey(session);
    final notifyEnabled = _notifyEnabled[notifyKey] ?? false;
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasTime)
                  IconButton(
                    icon: Icon(
                      notifyEnabled
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                      color: notifyEnabled
                          ? AppColors.of(context).f1Red
                          : AppColors.of(context).textMuted,
                    ),
                  onPressed: () => _toggleSessionNotification(session),
                  ),
                IconButton(
                  icon: Icon(
                    Icons.calendar_month,
                    color: AppColors.of(context).textMuted,
                  ),
                  onPressed: () => _addSessionToCalendar(context, session),
                ),
              ],
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
      race: widget.race,
      session: session,
      season: widget.season,
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

  Future<void> _toggleSessionNotification(RaceSession session) async {
    final key = _sessionKey(session);
    final isEnabled = _notifyEnabled[key] ?? false;
    if (isEnabled) {
      await NotificationService.cancelSessionNotification(
        race: widget.race,
        session: session,
        season: widget.season,
      );
      await NotificationPreferences.setSessionEnabled(
        race: widget.race,
        session: session,
        season: widget.season,
        value: false,
      );
      if (mounted) {
        setState(() {
          _notifyEnabled[key] = false;
        });
      }
      _showSnack('Reminder removed.');
      return;
    }

    final scheduled = await NotificationService.scheduleSessionNotification(
      race: widget.race,
      session: session,
      season: widget.season,
      leadTime: _leadTime,
    );
    if (!scheduled) {
      _showSnack('Unable to schedule reminder.');
      return;
    }

    await NotificationPreferences.setSessionEnabled(
      race: widget.race,
      session: session,
      season: widget.season,
      value: true,
    );
    if (mounted) {
      setState(() {
        _notifyEnabled[key] = true;
      });
    }
    _showSnack('Reminder set ${_leadTime.inMinutes} minutes before.');
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
