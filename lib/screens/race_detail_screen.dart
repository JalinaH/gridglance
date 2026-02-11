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

  const RaceDetailScreen({super.key, required this.race, required this.season});

  @override
  State<RaceDetailScreen> createState() => _RaceDetailScreenState();
}

class _RaceDetailScreenState extends State<RaceDetailScreen> {
  late final List<RaceSession> _sessions;
  final Map<String, bool> _sessionReminderEnabled = {};
  final Map<String, int> _sessionLeadMinutes = {};
  bool _weekendDigestEnabled = false;
  bool _loadingNotificationPreferences = true;

  @override
  void initState() {
    super.initState();
    _sessions = widget.race.sessions
        .where((session) => session.date.isNotEmpty)
        .toList();
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    final sessionEnabled = <String, bool>{};
    final sessionLeadMinutes = <String, int>{};

    for (final session in _sessions) {
      final key = _sessionKey(session);
      sessionEnabled[key] = await NotificationPreferences.isSessionEnabled(
        race: widget.race,
        session: session,
        season: widget.season,
      );
      sessionLeadMinutes[key] =
          await NotificationPreferences.getSessionLeadTimeMinutes(
            race: widget.race,
            session: session,
            season: widget.season,
          );
    }

    final weekendDigest = await NotificationPreferences.isWeekendDigestEnabled(
      race: widget.race,
      season: widget.season,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _sessionReminderEnabled
        ..clear()
        ..addAll(sessionEnabled);
      _sessionLeadMinutes
        ..clear()
        ..addAll(sessionLeadMinutes);
      _weekendDigestEnabled = weekendDigest;
      _loadingNotificationPreferences = false;
    });
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
        actions: [],
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
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
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
          _buildNotificationCard(context),
        ],
      ),
    );
  }

  List<Widget> _buildSessionRows(BuildContext context) {
    if (_sessions.isEmpty) {
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

    return _sessions
        .map((session) => _buildSessionRow(context, session))
        .toList();
  }

  Widget _buildNotificationCard(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    if (_sessions.isEmpty) {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Notifications",
              style: TextStyle(
                color: onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Session reminders are unavailable until schedule data is published.",
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Notifications",
                style: TextStyle(
                  color: onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Spacer(),
              if (_loadingNotificationPreferences)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.f1RedBright,
                  ),
                ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            "Toggle reminders per session and pick when to be notified.",
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
          SizedBox(height: 12),
          ..._buildSessionReminderRows(context),
          Divider(color: colors.border),
          SizedBox(height: 6),
          _buildWeekendDigestRow(context),
        ],
      ),
    );
  }

  List<Widget> _buildSessionReminderRows(BuildContext context) {
    return List.generate(_sessions.length, (index) {
      final session = _sessions[index];
      final isLast = index == _sessions.length - 1;
      return Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
        child: _buildSessionReminderRow(context, session),
      );
    });
  }

  Widget _buildSessionReminderRow(BuildContext context, RaceSession session) {
    final colors = AppColors.of(context);
    final key = _sessionKey(session);
    final reminderEnabled = _sessionReminderEnabled[key] ?? false;
    final selectedLead =
        _sessionLeadMinutes[key] ??
        NotificationPreferences.defaultLeadTimeMinutes;
    final start = session.startDateTime;
    final hasTimedStart =
        start != null && session.time != null && session.time!.isNotEmpty;
    final sessionIsFuture = start != null && start.isAfter(DateTime.now());
    final canConfigure =
        !_loadingNotificationPreferences && hasTimedStart && sessionIsFuture;
    final valueLabel = start == null
        ? session.displayDateTime
        : formatLocalDateTime(context, start);

    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      valueLabel,
                      style: TextStyle(color: colors.textMuted, fontSize: 11),
                    ),
                    if (start != null)
                      Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: CountdownText(
                          target: start,
                          hideIfPast: false,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    if (!hasTimedStart)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          "Reminder unavailable until start time is published.",
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    if (hasTimedStart && !sessionIsFuture)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          "Session already started.",
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: reminderEnabled,
                onChanged: canConfigure
                    ? (value) => _toggleSessionReminder(session, value)
                    : null,
                activeTrackColor: colors.f1RedBright.withValues(alpha: 0.55),
                activeThumbColor: colors.f1RedBright,
              ),
            ],
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: NotificationPreferences.leadTimePresets
                .map(
                  (minutes) => ChoiceChip(
                    label: Text(_leadPresetLabel(minutes)),
                    selected: selectedLead == minutes,
                    onSelected: canConfigure
                        ? (_) => _selectSessionLeadTime(session, minutes)
                        : null,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekendDigestRow(BuildContext context) {
    final colors = AppColors.of(context);
    final canEnable = _hasUpcomingTimedSession;
    final canInteract =
        !_loadingNotificationPreferences &&
        (_weekendDigestEnabled || canEnable);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Weekend digest",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2),
              Text(
                "One summary reminder 24h before the first upcoming session.",
                style: TextStyle(color: colors.textMuted, fontSize: 11),
              ),
              if (!canEnable && !_weekendDigestEnabled)
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    "No upcoming timed sessions available for digest.",
                    style: TextStyle(color: colors.textMuted, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
        Switch.adaptive(
          value: _weekendDigestEnabled,
          onChanged: canInteract ? _toggleWeekendDigest : null,
          activeTrackColor: colors.f1RedBright.withValues(alpha: 0.55),
          activeThumbColor: colors.f1RedBright,
        ),
      ],
    );
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
          Expanded(child: value),
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _hasUpcomingTimedSession {
    final now = DateTime.now();
    return _sessions.any(
      (session) =>
          session.startDateTime != null &&
          session.time != null &&
          session.time!.isNotEmpty &&
          session.startDateTime!.isAfter(now),
    );
  }

  String _sessionKey(RaceSession session) {
    return NotificationService.sessionKey(
      race: widget.race,
      session: session,
      season: widget.season,
    );
  }

  String _leadPresetLabel(int minutes) {
    if (minutes == 60) {
      return '1h';
    }
    if (minutes == 1440) {
      return '24h';
    }
    if (minutes % 60 == 0) {
      return '${minutes ~/ 60}h';
    }
    return '${minutes}m';
  }

  Future<void> _toggleSessionReminder(RaceSession session, bool enabled) async {
    final key = _sessionKey(session);
    final leadMinutes =
        _sessionLeadMinutes[key] ??
        NotificationPreferences.defaultLeadTimeMinutes;
    if (enabled) {
      final result = await NotificationService.scheduleSessionNotification(
        race: widget.race,
        session: session,
        season: widget.season,
        leadTime: Duration(minutes: leadMinutes),
      );
      if (result == ScheduleResult.scheduled) {
        await NotificationPreferences.setSessionEnabled(
          race: widget.race,
          session: session,
          season: widget.season,
          value: true,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _sessionReminderEnabled[key] = true;
        });
        _showSnackBar(
          '${session.name} reminder set for ${_leadPresetLabel(leadMinutes)} before start.',
        );
        return;
      }
      await NotificationPreferences.setSessionEnabled(
        race: widget.race,
        session: session,
        season: widget.season,
        value: false,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _sessionReminderEnabled[key] = false;
      });
      _showSnackBar(_sessionScheduleFailureMessage(session, result));
      return;
    }

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
    if (!mounted) {
      return;
    }
    setState(() {
      _sessionReminderEnabled[key] = false;
    });
    _showSnackBar('${session.name} reminder turned off.');
  }

  Future<void> _selectSessionLeadTime(RaceSession session, int minutes) async {
    final key = _sessionKey(session);
    final previous =
        _sessionLeadMinutes[key] ??
        NotificationPreferences.defaultLeadTimeMinutes;
    if (previous == minutes) {
      return;
    }
    if (!NotificationPreferences.leadTimePresets.contains(minutes)) {
      return;
    }

    setState(() {
      _sessionLeadMinutes[key] = minutes;
    });
    await NotificationPreferences.setSessionLeadTimeMinutes(
      race: widget.race,
      session: session,
      season: widget.season,
      minutes: minutes,
    );

    final reminderEnabled = _sessionReminderEnabled[key] ?? false;
    if (!reminderEnabled) {
      return;
    }

    final result = await NotificationService.scheduleSessionNotification(
      race: widget.race,
      session: session,
      season: widget.season,
      leadTime: Duration(minutes: minutes),
    );
    if (result == ScheduleResult.scheduled) {
      _showSnackBar(
        '${session.name} lead time updated to ${_leadPresetLabel(minutes)}.',
      );
      return;
    }

    await NotificationPreferences.setSessionLeadTimeMinutes(
      race: widget.race,
      session: session,
      season: widget.season,
      minutes: previous,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _sessionLeadMinutes[key] = previous;
    });
    _showSnackBar(_sessionScheduleFailureMessage(session, result));
  }

  Future<void> _toggleWeekendDigest(bool enabled) async {
    if (enabled) {
      final result = await NotificationService.scheduleWeekendDigest(
        race: widget.race,
        season: widget.season,
      );
      if (result == ScheduleResult.scheduled) {
        await NotificationPreferences.setWeekendDigestEnabled(
          race: widget.race,
          season: widget.season,
          value: true,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _weekendDigestEnabled = true;
        });
        _showSnackBar('Weekend digest enabled.');
        return;
      }
      await NotificationPreferences.setWeekendDigestEnabled(
        race: widget.race,
        season: widget.season,
        value: false,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _weekendDigestEnabled = false;
      });
      _showSnackBar(_digestScheduleFailureMessage(result));
      return;
    }

    await NotificationService.cancelWeekendDigestNotification(
      race: widget.race,
      season: widget.season,
    );
    await NotificationPreferences.setWeekendDigestEnabled(
      race: widget.race,
      season: widget.season,
      value: false,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _weekendDigestEnabled = false;
    });
    _showSnackBar('Weekend digest turned off.');
  }

  String _sessionScheduleFailureMessage(
    RaceSession session,
    ScheduleResult result,
  ) {
    switch (result) {
      case ScheduleResult.missingTime:
        return '${session.name} start time is unavailable.';
      case ScheduleResult.inPast:
        return 'Lead time has already passed for ${session.name}.';
      case ScheduleResult.permissionDenied:
        return 'Notification permission denied.';
      case ScheduleResult.unavailable:
        return NotificationService.lastError ?? 'Unable to schedule reminder.';
      case ScheduleResult.scheduled:
        return '${session.name} reminder scheduled.';
    }
  }

  String _digestScheduleFailureMessage(ScheduleResult result) {
    switch (result) {
      case ScheduleResult.inPast:
        return 'No upcoming timed sessions available for digest.';
      case ScheduleResult.permissionDenied:
        return 'Notification permission denied.';
      case ScheduleResult.unavailable:
        return NotificationService.lastError ?? 'Unable to schedule digest.';
      case ScheduleResult.missingTime:
        return 'Session time unavailable for digest.';
      case ScheduleResult.scheduled:
        return 'Weekend digest scheduled.';
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
