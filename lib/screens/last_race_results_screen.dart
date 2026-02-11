import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../models/session_results.dart';
import '../theme/app_theme.dart';
import '../utils/date_time_format.dart';
import '../widgets/f1_scaffold.dart';
import '../widgets/season_cards.dart';

class LastRaceResultsScreen extends StatefulWidget {
  final String season;

  const LastRaceResultsScreen({super.key, required this.season});

  @override
  State<LastRaceResultsScreen> createState() => _LastRaceResultsScreenState();
}

class _LastRaceResultsScreenState extends State<LastRaceResultsScreen> {
  late final Future<SessionResults?> _raceFuture;
  late final Future<SessionResults?> _qualifyingFuture;
  late final Future<SessionResults?> _sprintFuture;
  SessionType _selected = SessionType.race;

  @override
  void initState() {
    super.initState();
    final api = ApiService();
    _raceFuture = api.getLastRaceResults(season: widget.season);
    _qualifyingFuture = api.getLastQualifyingResults(season: widget.season);
    _sprintFuture = api.getLastSprintResults(season: widget.season);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return F1Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last Race Results'),
            Text(
              'Season ${widget.season}',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: 24),
        physics: BouncingScrollPhysics(),
        children: [
          _buildRaceHeader(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildSegmentedControl(),
          ),
          _buildResultsBody(),
        ],
      ),
    );
  }

  Widget _buildRaceHeader() {
    final colors = AppColors.of(context);
    return FutureBuilder<SessionResults?>(
      future: _raceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return GlassCard(
            child: Row(
              children: [
                CircularProgressIndicator(color: colors.f1Red),
                SizedBox(width: 12),
                Text(
                  'Loading last race…',
                  style: TextStyle(color: colors.textMuted),
                ),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return GlassCard(
            child: Text(
              'Unable to load race results and no cache is available yet.',
              style: TextStyle(color: colors.textMuted),
            ),
          );
        }
        final results = snapshot.data;
        if (results == null) {
          return GlassCard(
            child: Text(
              'No recent race results available.',
              style: TextStyle(color: colors.textMuted),
            ),
          );
        }
        return RaceCard(race: results.race, highlight: true);
      },
    );
  }

  Widget _buildSegmentedControl() {
    final colors = AppColors.of(context);
    return Row(
      children: [
        _buildChip(
          label: 'Race',
          selected: _selected == SessionType.race,
          onTap: () => _setSelected(SessionType.race),
          colors: colors,
        ),
        SizedBox(width: 8),
        _buildChip(
          label: 'Qualifying',
          selected: _selected == SessionType.qualifying,
          onTap: () => _setSelected(SessionType.qualifying),
          colors: colors,
        ),
        SizedBox(width: 8),
        _buildChip(
          label: 'Sprint',
          selected: _selected == SessionType.sprint,
          onTap: () => _setSelected(SessionType.sprint),
          colors: colors,
        ),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required AppColors colors,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : colors.textMuted,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      selected: selected,
      selectedColor: colors.f1Red,
      backgroundColor: colors.surfaceAlt,
      onSelected: (_) => onTap(),
      shape: StadiumBorder(side: BorderSide(color: colors.border)),
    );
  }

  Widget _buildResultsBody() {
    Future<SessionResults?> future;
    switch (_selected) {
      case SessionType.qualifying:
        future = _qualifyingFuture;
        break;
      case SessionType.sprint:
        future = _sprintFuture;
        break;
      case SessionType.race:
        future = _raceFuture;
        break;
    }

    return FutureBuilder<SessionResults?>(
      future: future,
      builder: (context, snapshot) {
        final colors = AppColors.of(context);
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: colors.f1Red),
            ),
          );
        }
        if (snapshot.hasError) {
          return GlassCard(
            child: Text(
              'Unable to load results and no cache is available yet.',
              style: TextStyle(color: colors.textMuted),
            ),
          );
        }
        final results = snapshot.data;
        if (results == null || results.results.isEmpty) {
          return GlassCard(
            child: Text(
              _emptyLabel(),
              style: TextStyle(color: colors.textMuted),
            ),
          );
        }
        return Column(
          children: [
            if (results.lastUpdated != null)
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    results.isFromCache
                        ? '${formatLastUpdatedAgo(results.lastUpdated!)} • Offline cache'
                        : formatLastUpdatedAgo(results.lastUpdated!),
                    style: TextStyle(color: colors.textMuted, fontSize: 11),
                  ),
                ),
              ),
            _buildResultsCard(results),
          ],
        );
      },
    );
  }

  String _emptyLabel() {
    switch (_selected) {
      case SessionType.qualifying:
        return 'Qualifying results not available.';
      case SessionType.sprint:
        return 'Sprint results not available.';
      case SessionType.race:
        return 'Race results not available.';
    }
  }

  Widget _buildResultsCard(SessionResults session) {
    final results = _sortedResults(session.results);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResultsHeader(session),
          SizedBox(height: 10),
          ...results.map((result) => _buildResultRow(session, result)),
        ],
      ),
    );
  }

  Widget _buildResultsHeader(SessionResults session) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final raceStart = session.race.startDateTime;
    final dateLabel = raceStart == null
        ? session.race.date
        : (session.race.time == null || session.race.time!.isEmpty)
        ? formatLocalDate(context, raceStart)
        : formatLocalDateTime(context, raceStart);
    final title = _titleForSession(session.type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '${session.race.raceName} • $dateLabel',
          style: TextStyle(color: colors.textMuted, fontSize: 12),
        ),
        SizedBox(height: 10),
        _buildHeaderRow(session.type),
      ],
    );
  }

  Widget _buildHeaderRow(SessionType type) {
    final colors = AppColors.of(context);
    switch (type) {
      case SessionType.qualifying:
        return Row(
          children: [
            _headerCell('Pos', width: 36, colors: colors),
            _headerCell('Driver', flex: 1, colors: colors),
            _headerCell('Q1', width: 56, colors: colors, alignRight: true),
            _headerCell('Q2', width: 56, colors: colors, alignRight: true),
            _headerCell('Q3', width: 56, colors: colors, alignRight: true),
          ],
        );
      case SessionType.sprint:
      case SessionType.race:
        return Row(
          children: [
            _headerCell('Pos', width: 36, colors: colors),
            _headerCell('Driver', flex: 1, colors: colors),
            _headerCell('Time', width: 80, colors: colors, alignRight: true),
            _headerCell('Pts', width: 42, colors: colors, alignRight: true),
          ],
        );
    }
  }

  Widget _headerCell(
    String label, {
    required AppColors colors,
    double? width,
    int? flex,
    bool alignRight = false,
  }) {
    final text = Text(
      label,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        color: colors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    );
    if (width != null) {
      return SizedBox(width: width, child: text);
    }
    return Expanded(flex: flex ?? 1, child: text);
  }

  Widget _buildResultRow(SessionResults session, ResultEntry result) {
    final colors = AppColors.of(context);
    switch (session.type) {
      case SessionType.qualifying:
        return Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  result.position,
                  style: TextStyle(
                    color: colors.f1RedBright,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.driverName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      result.teamName,
                      style: TextStyle(color: colors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              _qualifyingCell(result.q1),
              _qualifyingCell(result.q2),
              _qualifyingCell(result.q3),
            ],
          ),
        );
      case SessionType.sprint:
      case SessionType.race:
        return Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  result.position,
                  style: TextStyle(
                    color: colors.f1RedBright,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.driverName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      result.teamName,
                      style: TextStyle(color: colors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  result.timeOrStatus,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 42,
                child: Text(
                  result.points,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _qualifyingCell(String? value) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: 56,
      child: Text(
        value == null || value.isEmpty ? '-' : value,
        textAlign: TextAlign.right,
        style: TextStyle(color: colors.textMuted, fontSize: 11),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  List<ResultEntry> _sortedResults(List<ResultEntry> results) {
    final sorted = List<ResultEntry>.from(results);
    sorted.sort((a, b) {
      final aPos = int.tryParse(a.position) ?? 999;
      final bPos = int.tryParse(b.position) ?? 999;
      return aPos.compareTo(bPos);
    });
    return sorted;
  }

  String _titleForSession(SessionType type) {
    switch (type) {
      case SessionType.qualifying:
        return 'Qualifying Results';
      case SessionType.sprint:
        return 'Sprint Results';
      case SessionType.race:
        return 'Race Results';
    }
  }

  void _setSelected(SessionType type) {
    if (_selected == type) {
      return;
    }
    setState(() {
      _selected = type;
    });
  }
}
