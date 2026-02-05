import 'dart:math';

import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../models/driver_standing.dart';
import '../models/race_result.dart';
import '../theme/app_theme.dart';
import '../utils/date_time_format.dart';
import '../widgets/f1_scaffold.dart';
import '../widgets/points_trend_chart.dart';
import '../widgets/season_cards.dart';
import '../widgets/team_logo.dart';

class DriverDetailScreen extends StatefulWidget {
  final DriverStanding driver;
  final String season;

  const DriverDetailScreen({
    super.key,
    required this.driver,
    required this.season,
  });

  @override
  State<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen> {
  late final Future<List<DriverRaceResult>> _resultsFuture;

  @override
  void initState() {
    super.initState();
    _resultsFuture = ApiService().getDriverResults(
      season: widget.season,
      driverId: widget.driver.driverId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return F1Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.driver.givenName} ${widget.driver.familyName}'),
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
          GlassCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TeamLogo(teamName: widget.driver.teamName, size: 40),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.driver.givenName} ${widget.driver.familyName}',
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.driver.teamName,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (widget.driver.permanentNumber != null &&
                              widget.driver.permanentNumber!.isNotEmpty)
                            _metaChip(
                              colors,
                              'No. ${widget.driver.permanentNumber}',
                            ),
                          if (widget.driver.code != null &&
                              widget.driver.code!.isNotEmpty)
                            _metaChip(
                              colors,
                              widget.driver.code!.toUpperCase(),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatPill(
                      text: _positionLabel(widget.driver.position),
                      color: colors.f1Red,
                    ),
                    SizedBox(height: 6),
                    StatPill(text: '${widget.driver.points} PTS'),
                    SizedBox(height: 6),
                    StatPill(text: '${widget.driver.wins} W'),
                  ],
                ),
              ],
            ),
          ),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Points per race',
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: 12),
                FutureBuilder<List<DriverRaceResult>>(
                  future: _resultsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(color: colors.f1Red),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Text(
                        'Failed to load chart data.',
                        style: TextStyle(color: colors.textMuted),
                      );
                    }
                    final results = _sortedResults(snapshot.data ?? []);
                    if (results.length < 2) {
                      return Text(
                        'Not enough data to chart yet.',
                        style: TextStyle(color: colors.textMuted),
                      );
                    }
                    final points = results
                        .map((result) => _parsePoints(result.points))
                        .toList();
                    final labels =
                        results.map((result) => 'R${result.round}').toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildChartStats(points),
                        SizedBox(height: 12),
                        PointsTrendChart(points: points, labels: labels),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Form',
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: 12),
                FutureBuilder<List<DriverRaceResult>>(
                  future: _resultsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: CircularProgressIndicator(color: colors.f1Red),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Text(
                        'Failed to load recent results.',
                        style: TextStyle(color: colors.textMuted),
                      );
                    }
                    final results = _recentResults(snapshot.data ?? []);
                    if (results.isEmpty) {
                      return Text(
                        'No results available.',
                        style: TextStyle(color: colors.textMuted),
                      );
                    }
                    return Column(
                      children: results
                          .map((result) => _buildResultRow(context, result))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<DriverRaceResult> _recentResults(List<DriverRaceResult> results) {
    final sorted = _sortedResults(results);
    if (sorted.length <= 5) {
      return sorted;
    }
    return sorted.sublist(max(0, sorted.length - 5));
  }

  List<DriverRaceResult> _sortedResults(List<DriverRaceResult> results) {
    final sorted = List<DriverRaceResult>.from(results)
      ..sort((a, b) => _roundValue(a.round).compareTo(_roundValue(b.round)));
    return sorted;
  }

  int _roundValue(String round) {
    return int.tryParse(round) ?? 0;
  }

  Widget _buildResultRow(BuildContext context, DriverRaceResult result) {
    final colors = AppColors.of(context);
    final dateTime = DateTime.tryParse(result.date);
    final dateLabel = dateTime == null
        ? result.date
        : formatLocalDate(context, dateTime);
    final statusLabel = _statusLabel(result.status);
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Text(
              'R${result.round}',
              style: TextStyle(
                color: colors.f1RedBright,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.raceName,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  statusLabel.isEmpty ? dateLabel : '$dateLabel • $statusLabel',
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatPill(text: _positionLabel(result.position)),
              SizedBox(height: 4),
              Text(
                '${result.points} pts',
                style: TextStyle(color: colors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(AppColors colors, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  String _positionLabel(String position) {
    final value = int.tryParse(position);
    if (value == null) {
      return position;
    }
    return 'P$position';
  }

  String _statusLabel(String status) {
    final label = status.trim();
    if (label.isEmpty || label == 'Finished') {
      return '';
    }
    return label;
  }

  Widget _buildChartStats(List<double> points) {
    final colors = AppColors.of(context);
    final total = points.fold(0.0, (sum, item) => sum + item);
    final avg = points.isEmpty ? 0.0 : total / points.length;
    final best = points.reduce(max);
    return Row(
      children: [
        _statChip(colors, 'Races', points.length.toString()),
        SizedBox(width: 8),
        _statChip(colors, 'Avg', _formatPoints(avg)),
        SizedBox(width: 8),
        _statChip(colors, 'Best', _formatPoints(best)),
      ],
    );
  }

  Widget _statChip(AppColors colors, String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  double _parsePoints(String value) {
    return double.tryParse(value) ?? 0.0;
  }

  String _formatPoints(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}
