import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../data/api_service.dart';
import '../models/constructor_standing.dart';
import '../models/driver_standing.dart';
import '../services/widget_update_service.dart';
import '../theme/app_theme.dart';

class WidgetsScreen extends StatefulWidget {
  const WidgetsScreen({super.key});

  @override
  State<WidgetsScreen> createState() => _WidgetsScreenState();
}

class _WidgetsScreenState extends State<WidgetsScreen> {
  bool _addingDriver = false;
  bool _addingTeam = false;
  String? _driverStatusMessage;
  String? _teamStatusMessage;
  late final String _season = DateTime.now().year.toString();
  late final Future<_WidgetPreviewData> _previewFuture;

  @override
  void initState() {
    super.initState();
    _previewFuture = _loadPreviewData();
  }

  Future<_WidgetPreviewData> _loadPreviewData() async {
    final api = ApiService();
    final drivers = await api.getDriverStandings(season: _season);
    final teams = await api.getConstructorStandings(season: _season);
    return _WidgetPreviewData(
      season: _season,
      drivers: drivers,
      teams: teams,
    );
  }

  Future<void> _addDriverWidget() async {
    setState(() {
      _addingDriver = true;
      _driverStatusMessage = null;
    });

    try {
      final supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
      if (!supported) {
        if (mounted) {
          setState(() {
            _driverStatusMessage =
                "Widget pinning not supported. Use widget picker.";
          });
        }
        return;
      }
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName:
            WidgetUpdateService.androidQualifiedDriverWidgetProvider,
      );
      if (mounted) {
        setState(() {
          _driverStatusMessage = "Widget add request sent";
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _driverStatusMessage = "Failed to request widget";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _addingDriver = false;
        });
      }
    }
  }

  Future<void> _addTeamWidget() async {
    setState(() {
      _addingTeam = true;
      _teamStatusMessage = null;
    });

    try {
      final supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
      if (!supported) {
        if (mounted) {
          setState(() {
            _teamStatusMessage =
                "Widget pinning not supported. Use widget picker.";
          });
        }
        return;
      }
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName:
            WidgetUpdateService.androidQualifiedTeamWidgetProvider,
      );
      if (mounted) {
        setState(() {
          _teamStatusMessage = "Widget add request sent";
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _teamStatusMessage = "Failed to request widget";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _addingTeam = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return FutureBuilder<_WidgetPreviewData>(
      future: _previewFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError;
        final data = snapshot.data;
        final seasonLabel = data?.season ?? _season;
        final driverEntries = _buildDriverEntries(
          data?.drivers,
          isLoading: isLoading,
          hasError: hasError,
        );
        final teamEntries = _buildTeamEntries(
          data?.teams,
          isLoading: isLoading,
          hasError: hasError,
        );
        final driverSubtitle =
            _driverSubtitle(isLoading, hasError, data?.drivers);
        final teamSubtitle = _teamSubtitle(isLoading, hasError, data?.teams);

        return ListView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              "Widgets",
              style: TextStyle(
                color: onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
            SizedBox(height: 16),
            _buildWidgetCard(
              context,
              preview: _DriverStandingsPreview(
                seasonLabel: seasonLabel,
                subtitle: driverSubtitle,
                entries: driverEntries,
              ),
              actionLabel: "Add widget",
              isAdding: _addingDriver,
              onAction: _addingDriver ? null : _addDriverWidget,
              statusMessage: _driverStatusMessage,
            ),
            _buildWidgetCard(
              context,
              preview: _TeamStandingsPreview(
                seasonLabel: seasonLabel,
                subtitle: teamSubtitle,
                entries: teamEntries,
              ),
              actionLabel: "Add widget",
              isAdding: _addingTeam,
              onAction: _addingTeam ? null : _addTeamWidget,
              statusMessage: _teamStatusMessage,
            ),
          ],
        );
      },
    );
  }

  List<_PreviewEntry> _buildDriverEntries(
    List<DriverStanding>? standings, {
    required bool isLoading,
    required bool hasError,
  }) {
    if (hasError) {
      return [
        _PreviewEntry(name: "Failed to load", points: ""),
        _PreviewEntry(name: "TBD", points: ""),
        _PreviewEntry(name: "TBD", points: ""),
      ];
    }
    if (isLoading) {
      return [
        _PreviewEntry(name: "Loading...", points: ""),
        _PreviewEntry(name: "Please wait", points: ""),
        _PreviewEntry(name: "Please wait", points: ""),
      ];
    }
    final top = (standings ?? []).take(3).toList();
    return List.generate(
      3,
      (index) {
        if (index >= top.length) {
          return _PreviewEntry(name: "TBD", points: "");
        }
        final driver = top[index];
        return _PreviewEntry(
          name: "${driver.givenName} ${driver.familyName}",
          points: "${driver.points} pts",
        );
      },
    );
  }

  List<_PreviewEntry> _buildTeamEntries(
    List<ConstructorStanding>? standings, {
    required bool isLoading,
    required bool hasError,
  }) {
    if (hasError) {
      return [
        _PreviewEntry(name: "Failed to load", points: ""),
        _PreviewEntry(name: "TBD", points: ""),
        _PreviewEntry(name: "TBD", points: ""),
      ];
    }
    if (isLoading) {
      return [
        _PreviewEntry(name: "Loading...", points: ""),
        _PreviewEntry(name: "Please wait", points: ""),
        _PreviewEntry(name: "Please wait", points: ""),
      ];
    }
    final top = (standings ?? []).take(3).toList();
    return List.generate(
      3,
      (index) {
        if (index >= top.length) {
          return _PreviewEntry(name: "TBD", points: "");
        }
        final team = top[index];
        return _PreviewEntry(
          name: team.teamName,
          points: "${team.points} pts",
        );
      },
    );
  }

  String _driverSubtitle(
    bool isLoading,
    bool hasError,
    List<DriverStanding>? standings,
  ) {
    if (hasError) {
      return "Unable to load";
    }
    if (isLoading) {
      return "Loading standings";
    }
    if (standings == null || standings.isEmpty) {
      return "Standings coming soon";
    }
    return "Top 3 drivers";
  }

  String _teamSubtitle(
    bool isLoading,
    bool hasError,
    List<ConstructorStanding>? standings,
  ) {
    if (hasError) {
      return "Unable to load";
    }
    if (isLoading) {
      return "Loading standings";
    }
    if (standings == null || standings.isEmpty) {
      return "Standings coming soon";
    }
    return "Top 3 teams";
  }

  Widget _buildWidgetCard(
    BuildContext context, {
    required Widget preview,
    required String actionLabel,
    required bool isAdding,
    required VoidCallback? onAction,
    String? statusMessage,
  }) {
    final colors = AppColors.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.06,
            ),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          preview,
          if (statusMessage != null) ...[
            SizedBox(height: 8),
            Text(
              statusMessage,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
          SizedBox(height: 10),
          SizedBox(
            height: 34,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.f1Red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            onPressed: onAction,
            child: Text(
                isAdding ? "Adding..." : actionLabel,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverStandingsPreview extends StatelessWidget {
  final String seasonLabel;
  final String subtitle;
  final List<_PreviewEntry> entries;

  const _DriverStandingsPreview({
    required this.seasonLabel,
    required this.subtitle,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    return AspectRatio(
      aspectRatio: 18 / 10,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.backgroundAlt,
              colors.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
              blurRadius: 12,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -32,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.f1RedBright.withValues(alpha: isDark ? 0.35 : 0.2),
                      colors.f1Red.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surfaceAlt.withValues(alpha: 0.5),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 3,
                        width: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colors.f1Red, colors.f1RedBright],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        "DRIVER STANDINGS",
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt.withValues(
                            alpha: isDark ? 0.9 : 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          seasonLabel,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  SizedBox(height: 10),
                  _StandingsRow(
                    position: "1",
                    name: entries[0].name,
                    points: entries[0].points,
                    highlight: true,
                  ),
                  SizedBox(height: 6),
                  _StandingsRow(
                    position: "2",
                    name: entries[1].name,
                    points: entries[1].points,
                  ),
                  SizedBox(height: 6),
                  _StandingsRow(
                    position: "3",
                    name: entries[2].name,
                    points: entries[2].points,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamStandingsPreview extends StatelessWidget {
  final String seasonLabel;
  final String subtitle;
  final List<_PreviewEntry> entries;

  const _TeamStandingsPreview({
    required this.seasonLabel,
    required this.subtitle,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    return AspectRatio(
      aspectRatio: 18 / 10,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.backgroundAlt,
              colors.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
              blurRadius: 10,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -24,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.f1RedBright.withValues(alpha: isDark ? 0.28 : 0.15),
                      colors.f1Red.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -24,
              bottom: -36,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surfaceAlt.withValues(alpha: 0.45),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 3,
                        width: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colors.f1Red, colors.f1RedBright],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        "TEAM STANDINGS",
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt.withValues(
                            alpha: isDark ? 0.9 : 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          seasonLabel,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  SizedBox(height: 10),
                  _StandingsRow(
                    position: "1",
                    name: entries[0].name,
                    points: entries[0].points,
                    highlight: true,
                  ),
                  SizedBox(height: 6),
                  _StandingsRow(
                    position: "2",
                    name: entries[1].name,
                    points: entries[1].points,
                  ),
                  SizedBox(height: 6),
                  _StandingsRow(
                    position: "3",
                    name: entries[2].name,
                    points: entries[2].points,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandingsRow extends StatelessWidget {
  final String position;
  final String name;
  final String points;
  final bool highlight;

  const _StandingsRow({
    required this.position,
    required this.name,
    required this.points,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final badgeFill = highlight
        ? colors.f1Red.withValues(alpha: 0.95)
        : colors.surfaceAlt;
    final rowBackground = highlight
        ? colors.surfaceAlt.withValues(alpha: 0.7)
        : Colors.transparent;
    final showPoints = points.isNotEmpty;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: rowBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? colors.border.withValues(alpha: 0.6)
              : Colors.transparent,
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeFill,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              position,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: highlight ? onSurface : colors.textMuted,
                fontSize: 11,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          if (showPoints)
            Text(
              points,
              style: TextStyle(
                color: highlight ? onSurface : colors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _WidgetPreviewData {
  final String season;
  final List<DriverStanding> drivers;
  final List<ConstructorStanding> teams;

  const _WidgetPreviewData({
    required this.season,
    required this.drivers,
    required this.teams,
  });
}

class _PreviewEntry {
  final String name;
  final String points;

  const _PreviewEntry({
    required this.name,
    required this.points,
  });
}
