import 'dart:math';

import 'package:flutter/material.dart';

import '../data/api_service.dart';
import '../models/constructor_standing.dart';
import '../models/driver_standing.dart';
import '../models/race_result.dart';
import '../theme/app_theme.dart';
import '../widgets/f1_scaffold.dart';
import '../widgets/head_to_head_points_chart.dart';
import '../widgets/season_cards.dart';

enum CompareMode { drivers, teams }

class CompareModeScreen extends StatefulWidget {
  final String season;

  const CompareModeScreen({super.key, required this.season});

  @override
  State<CompareModeScreen> createState() => _CompareModeScreenState();
}

class _CompareModeScreenState extends State<CompareModeScreen> {
  final ApiService _api = ApiService();
  late final Future<_CompareBootstrap> _bootstrapFuture;
  CompareMode _mode = CompareMode.drivers;
  bool _didSeedDefaults = false;
  bool _loadingComparison = false;
  String? _comparisonError;
  _ComparisonViewModel? _comparison;
  int _comparisonRequestId = 0;

  DriverStanding? _firstDriver;
  DriverStanding? _secondDriver;
  ConstructorStanding? _firstTeam;
  ConstructorStanding? _secondTeam;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _loadBootstrap();
  }

  Future<_CompareBootstrap> _loadBootstrap() async {
    final values = await Future.wait<Object>([
      _api.getDriverStandings(season: widget.season),
      _api.getConstructorStandings(season: widget.season),
    ]);
    return _CompareBootstrap(
      drivers: values[0] as List<DriverStanding>,
      teams: values[1] as List<ConstructorStanding>,
    );
  }

  void _seedDefaults(_CompareBootstrap data) {
    if (_didSeedDefaults) {
      return;
    }
    setState(() {
      _didSeedDefaults = true;
      _firstDriver = data.drivers.isNotEmpty ? data.drivers[0] : null;
      _secondDriver = data.drivers.length > 1 ? data.drivers[1] : null;
      _firstTeam = data.teams.isNotEmpty ? data.teams[0] : null;
      _secondTeam = data.teams.length > 1 ? data.teams[1] : null;
      if ((_firstDriver == null || _secondDriver == null) &&
          _firstTeam != null &&
          _secondTeam != null) {
        _mode = CompareMode.teams;
      } else if ((_firstTeam == null || _secondTeam == null) &&
          _firstDriver != null &&
          _secondDriver != null) {
        _mode = CompareMode.drivers;
      }
    });
    _refreshComparison();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return F1Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Compare Mode'),
            Text(
              'Season ${widget.season}',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      body: FutureBuilder<_CompareBootstrap>(
        future: _bootstrapFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: colors.f1Red),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Text(
                'Unable to load compare options.',
                style: TextStyle(color: colors.textMuted),
              ),
            );
          }
          final bootstrap = snapshot.data!;
          if (!_didSeedDefaults) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              _seedDefaults(bootstrap);
            });
          }
          return ListView(
            padding: EdgeInsets.only(bottom: 24),
            physics: BouncingScrollPhysics(),
            children: [
              _buildModeCard(bootstrap),
              _buildPickerCard(bootstrap),
              if (_loadingComparison)
                GlassCard(
                  child: Row(
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
                        'Building comparison...',
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                )
              else if (_comparisonError != null)
                GlassCard(
                  child: Text(
                    _comparisonError!,
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                )
              else if (_comparison != null)
                _buildComparisonCards(_comparison!),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModeCard(_CompareBootstrap data) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final driversEnabled = data.drivers.length >= 2;
    final teamsEnabled = data.teams.length >= 2;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Head-to-head',
            style: TextStyle(
              color: onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Pick two drivers or two teams and compare trend + race pace.',
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              ChoiceChip(
                label: Text('Drivers'),
                selected: _mode == CompareMode.drivers,
                selectedColor: colors.f1Red,
                backgroundColor: colors.surfaceAlt,
                labelStyle: TextStyle(
                  color: _mode == CompareMode.drivers
                      ? Colors.white
                      : colors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                onSelected: driversEnabled
                    ? (_) {
                        setState(() {
                          _mode = CompareMode.drivers;
                        });
                        _refreshComparison();
                      }
                    : null,
              ),
              SizedBox(width: 8),
              ChoiceChip(
                label: Text('Teams'),
                selected: _mode == CompareMode.teams,
                selectedColor: colors.f1Red,
                backgroundColor: colors.surfaceAlt,
                labelStyle: TextStyle(
                  color: _mode == CompareMode.teams
                      ? Colors.white
                      : colors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                onSelected: teamsEnabled
                    ? (_) {
                        setState(() {
                          _mode = CompareMode.teams;
                        });
                        _refreshComparison();
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickerCard(_CompareBootstrap data) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final firstLabel = _mode == CompareMode.drivers
        ? _displayDriverName(_firstDriver)
        : _firstTeam?.teamName ?? 'Pick first team';
    final secondLabel = _mode == CompareMode.drivers
        ? _displayDriverName(_secondDriver)
        : _secondTeam?.teamName ?? 'Pick second team';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _mode == CompareMode.drivers ? 'Driver picks' : 'Team picks',
            style: TextStyle(
              color: onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(height: 10),
          _buildPickerRow(
            label: 'Entity A',
            value: firstLabel,
            onTap: () => _mode == CompareMode.drivers
                ? _pickDriver(isFirst: true, data: data)
                : _pickTeam(isFirst: true, data: data),
          ),
          SizedBox(height: 8),
          _buildPickerRow(
            label: 'Entity B',
            value: secondLabel,
            onTap: () => _mode == CompareMode.drivers
                ? _pickDriver(isFirst: false, data: data)
                : _pickTeam(isFirst: false, data: data),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 11,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 4),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, color: colors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonCards(_ComparisonViewModel viewModel) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Points trend',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(height: 10),
              HeadToHeadPointsChart(
                firstPoints: viewModel.firstTrend,
                secondPoints: viewModel.secondTrend,
                labels: viewModel.trendLabels,
                firstLabel: viewModel.first.label,
                secondLabel: viewModel.second.label,
              ),
            ],
          ),
        ),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Head-to-head metrics',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(height: 10),
              _buildMetricTable(viewModel),
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  _qualiDeltaLabel(viewModel),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTable(_ComparisonViewModel viewModel) {
    final colors = AppColors.of(context);
    return Column(
      children: [
        _metricRow(
          metric: 'Total points',
          first: _decimal(viewModel.first.totalPoints),
          second: _decimal(viewModel.second.totalPoints),
        ),
        _metricRow(
          metric: 'Wins',
          first: viewModel.first.wins.toString(),
          second: viewModel.second.wins.toString(),
        ),
        _metricRow(
          metric: 'Podiums',
          first: viewModel.first.podiums.toString(),
          second: viewModel.second.podiums.toString(),
        ),
        _metricRow(
          metric: 'Avg finish',
          first: _avgOrDash(viewModel.first.avgFinish),
          second: _avgOrDash(viewModel.second.avgFinish),
          hint: 'Lower is better',
        ),
        _metricRow(
          metric: 'Best finish',
          first: _bestFinishLabel(viewModel.first.bestFinish),
          second: _bestFinishLabel(viewModel.second.bestFinish),
        ),
        _metricRow(
          metric: 'Avg quali',
          first: _avgOrDash(viewModel.first.avgQuali),
          second: _avgOrDash(viewModel.second.avgQuali),
          hint: 'Lower is better',
          isLast: true,
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'A: ${viewModel.first.label}',
                style: TextStyle(color: colors.textMuted, fontSize: 11),
              ),
            ),
            Expanded(
              child: Text(
                'B: ${viewModel.second.label}',
                textAlign: TextAlign.right,
                style: TextStyle(color: colors.textMuted, fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricRow({
    required String metric,
    required String first,
    required String second,
    String? hint,
    bool isLast = false,
  }) {
    final colors = AppColors.of(context);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: colors.border.withValues(alpha: 0.7)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hint != null)
                  Text(
                    hint,
                    style: TextStyle(color: colors.textMuted, fontSize: 10),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              first,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              second,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDriver({
    required bool isFirst,
    required _CompareBootstrap data,
  }) async {
    if (data.drivers.isEmpty) {
      return;
    }
    final disabledId = isFirst
        ? _secondDriver?.driverId
        : _firstDriver?.driverId;
    final currentId = isFirst
        ? _firstDriver?.driverId
        : _secondDriver?.driverId;
    final selection = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) {
        return _ComparePickerSheet(
          title: 'Select Driver',
          items: data.drivers
              .map(
                (driver) => _PickerItem(
                  id: driver.driverId,
                  title: '${driver.givenName} ${driver.familyName}',
                  subtitle: '${driver.teamName} • ${driver.points} pts',
                ),
              )
              .toList(),
          currentId: currentId,
          disabledId: disabledId,
        );
      },
    );
    if (selection == null) {
      return;
    }
    final picked = data.drivers.firstWhere(
      (driver) => driver.driverId == selection,
      orElse: () => data.drivers.first,
    );
    setState(() {
      if (isFirst) {
        _firstDriver = picked;
      } else {
        _secondDriver = picked;
      }
    });
    _refreshComparison();
  }

  Future<void> _pickTeam({
    required bool isFirst,
    required _CompareBootstrap data,
  }) async {
    if (data.teams.isEmpty) {
      return;
    }
    final disabledId = isFirst
        ? _secondTeam?.constructorId
        : _firstTeam?.constructorId;
    final currentId = isFirst
        ? _firstTeam?.constructorId
        : _secondTeam?.constructorId;
    final selection = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) {
        return _ComparePickerSheet(
          title: 'Select Team',
          items: data.teams
              .map(
                (team) => _PickerItem(
                  id: team.constructorId,
                  title: team.teamName,
                  subtitle: '${team.points} pts • P${team.position}',
                ),
              )
              .toList(),
          currentId: currentId,
          disabledId: disabledId,
        );
      },
    );
    if (selection == null) {
      return;
    }
    final picked = data.teams.firstWhere(
      (team) => team.constructorId == selection,
      orElse: () => data.teams.first,
    );
    setState(() {
      if (isFirst) {
        _firstTeam = picked;
      } else {
        _secondTeam = picked;
      }
    });
    _refreshComparison();
  }

  Future<void> _refreshComparison() async {
    final requestId = ++_comparisonRequestId;
    final canCompare = _mode == CompareMode.drivers
        ? _firstDriver != null &&
              _secondDriver != null &&
              _firstDriver!.driverId != _secondDriver!.driverId
        : _firstTeam != null &&
              _secondTeam != null &&
              _firstTeam!.constructorId != _secondTeam!.constructorId;
    if (!canCompare) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingComparison = false;
        _comparison = null;
        _comparisonError = 'Select two different entries to compare.';
      });
      return;
    }
    setState(() {
      _loadingComparison = true;
      _comparisonError = null;
    });

    try {
      final next = _mode == CompareMode.drivers
          ? await _buildDriverComparison()
          : await _buildTeamComparison();
      if (!mounted || requestId != _comparisonRequestId) {
        return;
      }
      setState(() {
        _comparison = next;
        _comparisonError = null;
      });
    } catch (_) {
      if (!mounted || requestId != _comparisonRequestId) {
        return;
      }
      setState(() {
        _comparison = null;
        _comparisonError = 'Failed to load head-to-head data.';
      });
    } finally {
      if (mounted && requestId == _comparisonRequestId) {
        setState(() {
          _loadingComparison = false;
        });
      }
    }
  }

  Future<_ComparisonViewModel> _buildDriverComparison() async {
    final first = _firstDriver!;
    final second = _secondDriver!;
    final values = await Future.wait<Object>([
      _api.getDriverResults(season: widget.season, driverId: first.driverId),
      _api.getDriverResults(season: widget.season, driverId: second.driverId),
      _api.getDriverSprintResults(
        season: widget.season,
        driverId: first.driverId,
      ),
      _api.getDriverSprintResults(
        season: widget.season,
        driverId: second.driverId,
      ),
      _api.getDriverQualifyingResults(
        season: widget.season,
        driverId: first.driverId,
      ),
      _api.getDriverQualifyingResults(
        season: widget.season,
        driverId: second.driverId,
      ),
    ]);

    final firstResults = values[0] as List<DriverRaceResult>;
    final secondResults = values[1] as List<DriverRaceResult>;
    final firstSprintResults = values[2] as List<DriverSprintResult>;
    final secondSprintResults = values[3] as List<DriverSprintResult>;
    final firstQualifying = values[4] as List<DriverQualifyingResult>;
    final secondQualifying = values[5] as List<DriverQualifyingResult>;

    final firstMetrics = _buildDriverMetrics(
      label: _displayDriverName(first),
      raceResults: firstResults,
      sprintResults: firstSprintResults,
      qualifyingResults: firstQualifying,
      seasonTotalPoints: _toDouble(first.points),
    );
    final secondMetrics = _buildDriverMetrics(
      label: _displayDriverName(second),
      raceResults: secondResults,
      sprintResults: secondSprintResults,
      qualifyingResults: secondQualifying,
      seasonTotalPoints: _toDouble(second.points),
    );
    return _buildViewModel(firstMetrics, secondMetrics);
  }

  Future<_ComparisonViewModel> _buildTeamComparison() async {
    final first = _firstTeam!;
    final second = _secondTeam!;
    final values = await Future.wait<Object>([
      _api.getConstructorResults(
        season: widget.season,
        constructorId: first.constructorId,
      ),
      _api.getConstructorResults(
        season: widget.season,
        constructorId: second.constructorId,
      ),
      _api.getConstructorSprintResults(
        season: widget.season,
        constructorId: first.constructorId,
      ),
      _api.getConstructorSprintResults(
        season: widget.season,
        constructorId: second.constructorId,
      ),
      _api.getConstructorQualifyingResults(
        season: widget.season,
        constructorId: first.constructorId,
      ),
      _api.getConstructorQualifyingResults(
        season: widget.season,
        constructorId: second.constructorId,
      ),
    ]);

    final firstResults = values[0] as List<TeamRaceResult>;
    final secondResults = values[1] as List<TeamRaceResult>;
    final firstSprintResults = values[2] as List<TeamSprintResult>;
    final secondSprintResults = values[3] as List<TeamSprintResult>;
    final firstQualifying = values[4] as List<TeamQualifyingResult>;
    final secondQualifying = values[5] as List<TeamQualifyingResult>;

    final firstMetrics = _buildTeamMetrics(
      label: first.teamName,
      raceResults: firstResults,
      sprintResults: firstSprintResults,
      qualifyingResults: firstQualifying,
      seasonTotalPoints: _toDouble(first.points),
    );
    final secondMetrics = _buildTeamMetrics(
      label: second.teamName,
      raceResults: secondResults,
      sprintResults: secondSprintResults,
      qualifyingResults: secondQualifying,
      seasonTotalPoints: _toDouble(second.points),
    );
    return _buildViewModel(firstMetrics, secondMetrics);
  }

  _ComparisonViewModel _buildViewModel(
    _EntityMetrics first,
    _EntityMetrics second,
  ) {
    final allRounds = <int>{
      ...first.cumulativeByRound.keys,
      ...second.cumulativeByRound.keys,
    }..removeWhere((round) => round <= 0);
    final rounds = allRounds.toList()..sort();
    final firstTrend = <double>[];
    final secondTrend = <double>[];
    var currentFirst = 0.0;
    var currentSecond = 0.0;
    for (final round in rounds) {
      currentFirst = first.cumulativeByRound[round] ?? currentFirst;
      currentSecond = second.cumulativeByRound[round] ?? currentSecond;
      firstTrend.add(currentFirst);
      secondTrend.add(currentSecond);
    }
    return _ComparisonViewModel(
      first: first,
      second: second,
      firstTrend: firstTrend,
      secondTrend: secondTrend,
      trendLabels: rounds.map((round) => 'R$round').toList(),
    );
  }

  _EntityMetrics _buildDriverMetrics({
    required String label,
    required List<DriverRaceResult> raceResults,
    required List<DriverSprintResult> sprintResults,
    required List<DriverQualifyingResult> qualifyingResults,
    required double seasonTotalPoints,
  }) {
    final sortedRaceResults = List<DriverRaceResult>.from(raceResults)
      ..sort((a, b) => _roundNumber(a.round).compareTo(_roundNumber(b.round)));
    final cumulativeByRound = <int, double>{};
    final pointsByRound = <int, double>{};
    final finishPositions = <int>[];
    var wins = 0;
    var podiums = 0;

    for (final result in sortedRaceResults) {
      final round = _roundNumber(result.round);
      if (round <= 0) {
        continue;
      }
      pointsByRound[round] =
          (pointsByRound[round] ?? 0) + _toDouble(result.points);
      final position = _positionNumber(result.position);
      if (position != null) {
        finishPositions.add(position);
        if (position == 1) {
          wins += 1;
        }
        if (position <= 3) {
          podiums += 1;
        }
      }
    }

    for (final result in sprintResults) {
      final round = _roundNumber(result.round);
      if (round <= 0) {
        continue;
      }
      pointsByRound[round] =
          (pointsByRound[round] ?? 0) + _toDouble(result.points);
    }

    final rounds = pointsByRound.keys.toList()..sort();
    var cumulativePoints = 0.0;
    for (final round in rounds) {
      cumulativePoints += pointsByRound[round] ?? 0;
      cumulativeByRound[round] = cumulativePoints;
    }
    if (rounds.isNotEmpty) {
      cumulativeByRound[rounds.last] = seasonTotalPoints;
    }

    final qualifyingPositions = qualifyingResults
        .map((result) => _positionNumber(result.position))
        .whereType<int>()
        .toList();
    return _EntityMetrics(
      label: label,
      totalPoints: seasonTotalPoints,
      wins: wins,
      podiums: podiums,
      avgFinish: _averageInt(finishPositions),
      bestFinish: finishPositions.isEmpty ? null : finishPositions.reduce(min),
      avgQuali: _averageInt(qualifyingPositions),
      cumulativeByRound: cumulativeByRound,
    );
  }

  _EntityMetrics _buildTeamMetrics({
    required String label,
    required List<TeamRaceResult> raceResults,
    required List<TeamSprintResult> sprintResults,
    required List<TeamQualifyingResult> qualifyingResults,
    required double seasonTotalPoints,
  }) {
    final sortedRaceResults = List<TeamRaceResult>.from(raceResults)
      ..sort((a, b) => _roundNumber(a.round).compareTo(_roundNumber(b.round)));
    final cumulativeByRound = <int, double>{};
    final pointsByRound = <int, double>{};
    final finishPositions = <int>[];
    var wins = 0;
    var podiums = 0;

    for (final race in sortedRaceResults) {
      final round = _roundNumber(race.round);
      if (round <= 0) {
        continue;
      }
      final racePoints = race.drivers.fold<double>(
        0.0,
        (sum, driver) => sum + _toDouble(driver.points),
      );
      pointsByRound[round] = (pointsByRound[round] ?? 0) + racePoints;

      for (final driver in race.drivers) {
        final position = _positionNumber(driver.position);
        if (position == null) {
          continue;
        }
        finishPositions.add(position);
        if (position == 1) {
          wins += 1;
        }
        if (position <= 3) {
          podiums += 1;
        }
      }
    }

    for (final race in sprintResults) {
      final round = _roundNumber(race.round);
      if (round <= 0) {
        continue;
      }
      final sprintPoints = race.points.fold<double>(
        0.0,
        (sum, points) => sum + _toDouble(points),
      );
      pointsByRound[round] = (pointsByRound[round] ?? 0) + sprintPoints;
    }

    final rounds = pointsByRound.keys.toList()..sort();
    var cumulativePoints = 0.0;
    for (final round in rounds) {
      cumulativePoints += pointsByRound[round] ?? 0;
      cumulativeByRound[round] = cumulativePoints;
    }
    if (rounds.isNotEmpty) {
      cumulativeByRound[rounds.last] = seasonTotalPoints;
    }

    final qualifyingPositions = qualifyingResults
        .expand((result) => result.positions)
        .map(_positionNumber)
        .whereType<int>()
        .toList();

    return _EntityMetrics(
      label: label,
      totalPoints: seasonTotalPoints,
      wins: wins,
      podiums: podiums,
      avgFinish: _averageInt(finishPositions),
      bestFinish: finishPositions.isEmpty ? null : finishPositions.reduce(min),
      avgQuali: _averageInt(qualifyingPositions),
      cumulativeByRound: cumulativeByRound,
    );
  }

  String _displayDriverName(DriverStanding? driver) {
    if (driver == null) {
      return 'Pick driver';
    }
    return '${driver.givenName} ${driver.familyName}';
  }

  String _qualiDeltaLabel(_ComparisonViewModel viewModel) {
    final first = viewModel.first.avgQuali;
    final second = viewModel.second.avgQuali;
    if (first == null || second == null) {
      return 'Qualifying delta unavailable (missing data).';
    }
    final delta = first - second;
    final absolute = delta.abs().toStringAsFixed(2);
    if (delta == 0) {
      return 'Qualifying delta: dead even on average.';
    }
    final leader = delta < 0 ? viewModel.first.label : viewModel.second.label;
    return 'Qualifying delta: $leader ahead by $absolute positions on average.';
  }

  double _toDouble(String value) => double.tryParse(value) ?? 0.0;

  int _roundNumber(String round) => int.tryParse(round) ?? 0;

  int? _positionNumber(String value) {
    final number = int.tryParse(value);
    if (number == null || number <= 0) {
      return null;
    }
    return number;
  }

  double? _averageInt(List<int> values) {
    if (values.isEmpty) {
      return null;
    }
    final total = values.fold<int>(0, (sum, value) => sum + value);
    return total / values.length;
  }

  String _decimal(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  String _avgOrDash(double? value) {
    if (value == null) {
      return '--';
    }
    return value.toStringAsFixed(2);
  }

  String _bestFinishLabel(int? value) {
    if (value == null) {
      return '--';
    }
    return 'P$value';
  }
}

class _CompareBootstrap {
  final List<DriverStanding> drivers;
  final List<ConstructorStanding> teams;

  const _CompareBootstrap({required this.drivers, required this.teams});
}

class _EntityMetrics {
  final String label;
  final double totalPoints;
  final int wins;
  final int podiums;
  final double? avgFinish;
  final int? bestFinish;
  final double? avgQuali;
  final Map<int, double> cumulativeByRound;

  const _EntityMetrics({
    required this.label,
    required this.totalPoints,
    required this.wins,
    required this.podiums,
    required this.avgFinish,
    required this.bestFinish,
    required this.avgQuali,
    required this.cumulativeByRound,
  });
}

class _ComparisonViewModel {
  final _EntityMetrics first;
  final _EntityMetrics second;
  final List<double> firstTrend;
  final List<double> secondTrend;
  final List<String> trendLabels;

  const _ComparisonViewModel({
    required this.first,
    required this.second,
    required this.firstTrend,
    required this.secondTrend,
    required this.trendLabels,
  });
}

class _PickerItem {
  final String id;
  final String title;
  final String subtitle;

  const _PickerItem({
    required this.id,
    required this.title,
    required this.subtitle,
  });
}

class _ComparePickerSheet extends StatefulWidget {
  final String title;
  final List<_PickerItem> items;
  final String? currentId;
  final String? disabledId;

  const _ComparePickerSheet({
    required this.title,
    required this.items,
    required this.currentId,
    required this.disabledId,
  });

  @override
  State<_ComparePickerSheet> createState() => _ComparePickerSheetState();
}

class _ComparePickerSheetState extends State<_ComparePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final filtered = widget.items.where((item) {
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) {
        return true;
      }
      return item.title.toLowerCase().contains(query) ||
          item.subtitle.toLowerCase().contains(query);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.74,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: colors.textMuted),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(color: colors.textMuted),
                prefixIcon: Icon(Icons.search, color: colors.textMuted),
                filled: true,
                fillColor: colors.surfaceAlt,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.f1Red),
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matches.',
                      style: TextStyle(color: colors.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => Divider(color: colors.border),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final disabled = item.id == widget.disabledId;
                      final selected = item.id == widget.currentId;
                      return ListTile(
                        enabled: !disabled,
                        title: Text(
                          item.title,
                          style: TextStyle(
                            color: disabled
                                ? colors.textMuted.withValues(alpha: 0.6)
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          disabled
                              ? '${item.subtitle} • already selected'
                              : item.subtitle,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: selected
                            ? Icon(Icons.check, color: colors.f1RedBright)
                            : null,
                        onTap: disabled
                            ? null
                            : () => Navigator.of(context).pop(item.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
