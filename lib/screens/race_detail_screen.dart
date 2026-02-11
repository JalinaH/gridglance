import 'package:flutter/material.dart';
import '../models/race.dart';
import '../services/calendar_service.dart';
import '../services/share_card_service.dart';
import '../services/favorite_result_alert_service.dart';
import '../services/notification_preferences.dart';
import '../services/notification_service.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_time_format.dart';
import '../widgets/countdown_text.dart';
import '../widgets/f1_scaffold.dart';
import '../widgets/season_cards.dart';
import '../widgets/share_cards.dart';

class RaceDetailScreen extends StatefulWidget {
  final Race race;
  final String season;

  const RaceDetailScreen({super.key, required this.race, required this.season});

  @override
  State<RaceDetailScreen> createState() => _RaceDetailScreenState();
}

class _RaceDetailScreenState extends State<RaceDetailScreen> {
  late final List<RaceSession> _sessions;
  late final Future<WeekendWeather?> _weatherFuture;
  final GlobalKey _countdownShareCardKey = GlobalKey();
  final Map<String, bool> _sessionReminderEnabled = {};
  final Map<String, int> _sessionLeadMinutes = {};
  bool _weekendDigestEnabled = false;
  bool _favoriteSessionFinishedAlertsEnabled = false;
  bool _favoritePositionPointsAlertsEnabled = false;
  bool _loadingNotificationPreferences = true;
  bool _importingWeekendCalendar = false;
  bool _sharingCountdownCard = false;

  @override
  void initState() {
    super.initState();
    _sessions =
        widget.race.sessions
            .where((session) => session.date.isNotEmpty)
            .toList()
          ..sort(_sortSessions);
    _weatherFuture = WeatherService().getRaceWeekendWeather(widget.race);
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
    final favoriteSessionFinished =
        await NotificationPreferences.isFavoriteSessionFinishedEnabled();
    final favoritePositionPoints =
        await NotificationPreferences.isFavoritePositionPointsEnabled();

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
      _favoriteSessionFinishedAlertsEnabled = favoriteSessionFinished;
      _favoritePositionPointsAlertsEnabled = favoritePositionPoints;
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
            Text("Race Weekend Center"),
            Text(
              "${widget.race.raceName} • ${widget.season}",
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Share race countdown',
            onPressed: _sharingCountdownCard ? null : _shareCountdownCard,
            icon: _sharingCountdownCard
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.f1RedBright,
                    ),
                  )
                : Icon(Icons.ios_share, color: colors.f1RedBright),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: 24),
        physics: BouncingScrollPhysics(),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: RepaintBoundary(
              key: _countdownShareCardKey,
              child: RaceCountdownShareCard(
                race: widget.race,
                season: widget.season,
              ),
            ),
          ),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Track info",
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 10),
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
                if (widget.race.latitude != null &&
                    widget.race.longitude != null)
                  _buildDetailRow(
                    context,
                    "Coords",
                    '${widget.race.latitude!.toStringAsFixed(3)}, ${widget.race.longitude!.toStringAsFixed(3)}',
                  ),
              ],
            ),
          ),
          _buildWeatherCard(context),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Weekend sessions",
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _importingWeekendCalendar
                          ? null
                          : _addWeekendToCalendar,
                      icon: _importingWeekendCalendar
                          ? SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.f1RedBright,
                              ),
                            )
                          : Icon(
                              Icons.calendar_month,
                              size: 16,
                              color: colors.f1RedBright,
                            ),
                      label: Text(
                        _importingWeekendCalendar
                            ? "Importing..."
                            : "Add all to calendar",
                        style: TextStyle(
                          color: colors.f1RedBright,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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

  Widget _buildWeatherCard(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GlassCard(
      child: FutureBuilder<WeekendWeather?>(
        future: _weatherFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Weather outlook",
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.f1RedBright,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Loading weather...",
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Weather outlook",
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Weather data is unavailable right now.",
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ],
            );
          }

          final weather = snapshot.data;
          if (weather == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Weather outlook",
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Weather preview unavailable for this track.",
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ],
            );
          }

          final current = weather.current;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Weather outlook",
                style: TextStyle(
                  color: onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              if (current != null) ...[
                SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      _weatherIcon(current.weatherCode),
                      color: colors.f1RedBright,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        WeatherService.labelForCode(current.weatherCode),
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _temperatureLabel(current.temperatureC),
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (current.windSpeedKph != null)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Wind ${current.windSpeedKph!.round()} km/h',
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ),
              ],
              if (weather.daily.isNotEmpty) ...[
                SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: weather.daily.map((day) {
                    return _buildWeatherDayTile(context, day);
                  }).toList(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildWeatherDayTile(BuildContext context, WeatherDaily day) {
    final colors = AppColors.of(context);
    return Container(
      width: 128,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatLocalDate(context, day.date),
            style: TextStyle(color: colors.textMuted, fontSize: 11),
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Icon(
                _weatherIcon(day.weatherCode),
                size: 16,
                color: colors.f1Red,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  _temperatureRangeLabel(day.lowC, day.highC),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            WeatherService.labelForCode(day.weatherCode),
            style: TextStyle(color: colors.textMuted, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (day.precipitationChance != null)
            Text(
              'Rain ${day.precipitationChance}%',
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
        ],
      ),
    );
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
            "Manage pre-session reminders and favorite result alerts.",
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
          SizedBox(height: 12),
          ..._buildSessionReminderRows(context),
          Divider(color: colors.border),
          SizedBox(height: 6),
          _buildWeekendDigestRow(context),
          SizedBox(height: 12),
          Divider(color: colors.border),
          SizedBox(height: 6),
          _buildFavoriteResultAlerts(context),
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

  Widget _buildFavoriteResultAlerts(BuildContext context) {
    final colors = AppColors.of(context);
    final canInteract = !_loadingNotificationPreferences;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Favorite result alerts",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2),
        Text(
          "Get alerts for your favorite driver/team after sessions and standings updates.",
          style: TextStyle(color: colors.textMuted, fontSize: 11),
        ),
        SizedBox(height: 8),
        _buildFavoriteAlertToggle(
          context: context,
          title: "Session finished",
          subtitle: "Sent when race, sprint, or qualifying results are posted.",
          value: _favoriteSessionFinishedAlertsEnabled,
          onChanged: canInteract ? _toggleFavoriteSessionFinishedAlerts : null,
        ),
        SizedBox(height: 8),
        _buildFavoriteAlertToggle(
          context: context,
          title: "Position / points updates",
          subtitle:
              "Sent when your favorite's standings position or points change.",
          value: _favoritePositionPointsAlertsEnabled,
          onChanged: canInteract ? _toggleFavoritePositionPointsAlerts : null,
        ),
      ],
    );
  }

  Widget _buildFavoriteAlertToggle({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final colors = AppColors.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: colors.f1RedBright.withValues(alpha: 0.55),
            activeThumbColor: colors.f1RedBright,
          ),
        ],
      ),
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

  Future<void> _addWeekendToCalendar() async {
    if (_importingWeekendCalendar) {
      return;
    }
    setState(() {
      _importingWeekendCalendar = true;
    });

    final result = await CalendarService.addRaceWeekendToCalendar(
      race: widget.race,
      season: widget.season,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _importingWeekendCalendar = false;
    });

    if (result.total == 0) {
      _showSnackBar('Session schedule unavailable for calendar import.');
      return;
    }
    if (result.added == result.total) {
      _showSnackBar('Added ${result.added} sessions to calendar.');
      return;
    }
    if (result.added == 0) {
      _showSnackBar('Unable to add sessions to calendar.');
      return;
    }
    _showSnackBar('Added ${result.added} of ${result.total} sessions.');
  }

  int _sortSessions(RaceSession a, RaceSession b) {
    final first = a.startDateTime;
    final second = b.startDateTime;
    if (first == null && second == null) {
      return a.name.compareTo(b.name);
    }
    if (first == null) {
      return 1;
    }
    if (second == null) {
      return -1;
    }
    return first.compareTo(second);
  }

  IconData _weatherIcon(int? code) {
    switch (code) {
      case 0:
        return Icons.wb_sunny;
      case 1:
      case 2:
      case 3:
        return Icons.cloud;
      case 45:
      case 48:
        return Icons.cloud;
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return Icons.umbrella;
      case 71:
      case 73:
      case 75:
      case 85:
      case 86:
        return Icons.ac_unit;
      case 95:
      case 96:
      case 99:
        return Icons.flash_on;
      default:
        return Icons.cloud;
    }
  }

  String _temperatureLabel(double? value) {
    if (value == null) {
      return '--';
    }
    return '${value.round()}\u00B0C';
  }

  String _temperatureRangeLabel(double? low, double? high) {
    if (low == null && high == null) {
      return '--';
    }
    if (low == null) {
      return '${high!.round()}\u00B0C';
    }
    if (high == null) {
      return '${low.round()}\u00B0C';
    }
    return '${low.round()}\u00B0 / ${high.round()}\u00B0';
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

  Future<void> _toggleFavoriteSessionFinishedAlerts(bool enabled) async {
    if (enabled) {
      final allowed = await NotificationService.requestPermissions();
      if (!allowed) {
        _showSnackBar('Notification permission denied.');
        return;
      }
    }
    await NotificationPreferences.setFavoriteSessionFinishedEnabled(enabled);
    if (enabled) {
      await FavoriteResultAlertService.checkForUpdates(season: widget.season);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _favoriteSessionFinishedAlertsEnabled = enabled;
    });
    _showSnackBar(
      enabled
          ? 'Favorite session-finished alerts enabled.'
          : 'Favorite session-finished alerts turned off.',
    );
  }

  Future<void> _toggleFavoritePositionPointsAlerts(bool enabled) async {
    if (enabled) {
      final allowed = await NotificationService.requestPermissions();
      if (!allowed) {
        _showSnackBar('Notification permission denied.');
        return;
      }
    }
    await NotificationPreferences.setFavoritePositionPointsEnabled(enabled);
    if (enabled) {
      await FavoriteResultAlertService.checkForUpdates(season: widget.season);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _favoritePositionPointsAlertsEnabled = enabled;
    });
    _showSnackBar(
      enabled
          ? 'Favorite position/points alerts enabled.'
          : 'Favorite position/points alerts turned off.',
    );
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

  Future<void> _shareCountdownCard() async {
    if (_sharingCountdownCard) {
      return;
    }
    setState(() {
      _sharingCountdownCard = true;
    });
    try {
      await ShareCardService.shareRepaintBoundary(
        repaintBoundaryKey: _countdownShareCardKey,
        devicePixelRatio: View.of(context).devicePixelRatio,
        fileName: 'race-countdown-${widget.season}-round-${widget.race.round}',
        text: '${widget.race.raceName} countdown via GridGlance',
        subject: 'F1 Race Countdown',
      );
    } on ShareCardException catch (error) {
      _showSnackBar(error.message);
    } catch (_) {
      _showSnackBar('Unable to share race countdown right now.');
    } finally {
      if (mounted) {
        setState(() {
          _sharingCountdownCard = false;
        });
      }
    }
  }
}
