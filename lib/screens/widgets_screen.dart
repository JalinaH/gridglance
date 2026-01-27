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
  bool _addingFavoriteDriver = false;
  bool _addingFavoriteTeam = false;
  String? _favoriteDriverStatusMessage;
  String? _favoriteTeamStatusMessage;
  bool _driverWidgetTransparent = false;
  bool _teamWidgetTransparent = false;
  late final String _season = DateTime.now().year.toString();
  late final Future<_WidgetPreviewData> _previewFuture;
  _WidgetPreviewData? _previewData;

  @override
  void initState() {
    super.initState();
    _previewFuture = _loadPreviewData();
    _previewFuture.then((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _previewData = value;
      });
    });
    _loadTransparency();
  }

  Future<_WidgetPreviewData> _loadPreviewData() async {
    final api = ApiService();
    final drivers = await api.getDriverStandings(season: _season);
    final teams = await api.getConstructorStandings(season: _season);
    if (drivers.isEmpty && teams.isEmpty) {
      final fallbackSeason = (int.parse(_season) - 1).toString();
      final fallbackDrivers =
          await api.getDriverStandings(season: fallbackSeason);
      final fallbackTeams =
          await api.getConstructorStandings(season: fallbackSeason);
      if (fallbackDrivers.isNotEmpty || fallbackTeams.isNotEmpty) {
        return _WidgetPreviewData(
          season: fallbackSeason,
          drivers: fallbackDrivers,
          teams: fallbackTeams,
        );
      }
    }
    return _WidgetPreviewData(
      season: _season,
      drivers: drivers,
      teams: teams,
    );
  }

  Future<_WidgetPreviewData> _ensurePreviewData() async {
    final cached = _previewData;
    if (cached != null && (cached.drivers.isNotEmpty || cached.teams.isNotEmpty)) {
      return cached;
    }
    final data = await _loadPreviewData();
    if (mounted) {
      setState(() {
        _previewData = data;
      });
    }
    return data;
  }

  Future<void> _loadTransparency() async {
    final driverTransparent =
        await WidgetUpdateService.getDriverWidgetTransparent();
    final teamTransparent = await WidgetUpdateService.getTeamWidgetTransparent();
    if (!mounted) {
      return;
    }
    setState(() {
      _driverWidgetTransparent = driverTransparent;
      _teamWidgetTransparent = teamTransparent;
    });
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

  Future<void> _addFavoriteDriverWidget() async {
    final driver = await _pickFavoriteDriver();
    if (driver == null) {
      return;
    }
    try {
      final supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
      if (!supported) {
        if (mounted) {
          setState(() {
            _favoriteDriverStatusMessage =
                "Widget pinning not supported. Use widget picker.";
          });
        }
        return;
      }
      setState(() {
        _addingFavoriteDriver = true;
        _favoriteDriverStatusMessage = null;
      });
      await WidgetUpdateService.setFavoriteDriverDefault(
        driver: driver,
        season: _season,
      );
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName:
            WidgetUpdateService.androidQualifiedFavoriteDriverWidgetProvider,
      );
      if (mounted) {
        setState(() {
          _favoriteDriverStatusMessage = "Widget add request sent";
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _favoriteDriverStatusMessage = "Failed to request widget";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _addingFavoriteDriver = false;
        });
      }
    }
  }

  Future<void> _addFavoriteTeamWidget() async {
    final selection = await _pickFavoriteTeam();
    if (selection == null) {
      return;
    }
    try {
      final supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
      if (!supported) {
        if (mounted) {
          setState(() {
            _favoriteTeamStatusMessage =
                "Widget pinning not supported. Use widget picker.";
          });
        }
        return;
      }
      setState(() {
        _addingFavoriteTeam = true;
        _favoriteTeamStatusMessage = null;
      });
      await WidgetUpdateService.setFavoriteTeamDefault(
        team: selection.team,
        drivers: selection.drivers,
        season: _season,
      );
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName:
            WidgetUpdateService.androidQualifiedFavoriteTeamWidgetProvider,
      );
      if (mounted) {
        setState(() {
          _favoriteTeamStatusMessage = "Widget add request sent";
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _favoriteTeamStatusMessage = "Failed to request widget";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _addingFavoriteTeam = false;
        });
      }
    }
  }

  Future<DriverStanding?> _pickFavoriteDriver() async {
    return showModalBottomSheet<DriverStanding>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) {
        return _SelectionSheet<DriverStanding>(
          title: 'Select Driver',
          loadItems: () async {
            final data = await _ensurePreviewData();
            return data.drivers;
          },
          itemBuilder: (context, driver) => ListTile(
            title: Text(
              '${driver.givenName} ${driver.familyName}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            subtitle: Text(
              '${driver.teamName} • ${driver.points} pts',
              style: TextStyle(color: AppColors.of(context).textMuted),
            ),
            trailing: Text(
              'P${driver.position}',
              style: TextStyle(color: AppColors.of(context).textMuted),
            ),
            onTap: () => Navigator.of(context).pop(driver),
          ),
        );
      },
    );
  }

  Future<_TeamSelection?> _pickFavoriteTeam() async {
    return showModalBottomSheet<_TeamSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) {
        return _SelectionSheet<_TeamSelection>(
          title: 'Select Team',
          loadItems: () async {
            final data = await _ensurePreviewData();
            final teams = data.teams;
            final drivers = data.drivers;
            return teams.map((team) {
              final teamDrivers = drivers
                  .where((driver) => driver.constructorId == team.constructorId)
                  .take(2)
                  .toList();
              return _TeamSelection(team: team, drivers: teamDrivers);
            }).toList();
          },
          itemBuilder: (context, selection) {
            final driversLabel = selection.drivers.isEmpty
                ? 'Drivers TBD'
                : List.generate(
                    selection.drivers.length,
                    (index) => _shortDriverLabel(selection.drivers, index),
                  ).join('  ');
            return ListTile(
              title: Text(
                selection.team.teamName,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              subtitle: Text(
                '$driversLabel • ${selection.team.points} pts',
                style: TextStyle(color: AppColors.of(context).textMuted),
              ),
              trailing: Text(
                'P${selection.team.position}',
                style: TextStyle(color: AppColors.of(context).textMuted),
              ),
              onTap: () => Navigator.of(context).pop(selection),
            );
          },
        );
      },
    );
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
        final favoriteDriverPreview = _driverPreview(
          data?.drivers,
          isLoading: isLoading,
          hasError: hasError,
        );
        final favoriteTeamPreview = _teamPreview(
          data?.teams,
          isLoading: isLoading,
          hasError: hasError,
        );
        final favoriteTeamDriverLines = _teamDriverLines(
          data?.drivers,
          data?.teams,
          isLoading: isLoading,
          hasError: hasError,
        );
        final driverStandings = _driverStandingsPreview(
          data?.drivers,
          isLoading: isLoading,
          hasError: hasError,
        );
        final teamStandings = _teamStandingsPreview(
          data?.teams,
          isLoading: isLoading,
          hasError: hasError,
        );

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
              preview: _StandingsListPreview(
                seasonLabel: seasonLabel,
                title: 'Driver Standings',
                subtitle: 'Top 3 drivers',
                entries: driverStandings,
              ),
              option: _buildTransparencyToggle(
                context,
                value: _driverWidgetTransparent,
                onChanged: (value) async {
                  setState(() {
                    _driverWidgetTransparent = value;
                  });
                  await WidgetUpdateService.setDriverWidgetTransparent(value);
                },
              ),
              actionLabel: "Add widget",
              isAdding: _addingDriver,
              onAction: _addingDriver ? null : _addDriverWidget,
              statusMessage: _driverStatusMessage,
            ),
            _buildWidgetCard(
              context,
              preview: _StandingsListPreview(
                seasonLabel: seasonLabel,
                title: 'Team Standings',
                subtitle: 'Top 3 teams',
                entries: teamStandings,
              ),
              option: _buildTransparencyToggle(
                context,
                value: _teamWidgetTransparent,
                onChanged: (value) async {
                  setState(() {
                    _teamWidgetTransparent = value;
                  });
                  await WidgetUpdateService.setTeamWidgetTransparent(value);
                },
              ),
              actionLabel: "Add widget",
              isAdding: _addingTeam,
              onAction: _addingTeam ? null : _addTeamWidget,
              statusMessage: _teamStatusMessage,
            ),
            _buildWidgetCard(
              context,
              preview: _DriverStandingsPreview(
                seasonLabel: seasonLabel,
                preview: favoriteDriverPreview,
                title: 'Favorite Driver',
              ),
              actionLabel: "Add widget",
              isAdding: _addingFavoriteDriver,
              onAction: _addingFavoriteDriver ? null : _addFavoriteDriverWidget,
              statusMessage: _favoriteDriverStatusMessage,
            ),
            _buildWidgetCard(
              context,
              preview: _TeamStandingsPreview(
                seasonLabel: seasonLabel,
                preview: favoriteTeamPreview,
                driverLines: favoriteTeamDriverLines,
                title: 'Favorite Team',
              ),
              actionLabel: "Add widget",
              isAdding: _addingFavoriteTeam,
              onAction: _addingFavoriteTeam ? null : _addFavoriteTeamWidget,
              statusMessage: _favoriteTeamStatusMessage,
            ),
          ],
        );
      },
    );
  }

  _DriverPreviewData _driverPreview(
    List<DriverStanding>? standings, {
    required bool isLoading,
    required bool hasError,
  }) {
    if (hasError) {
      return _DriverPreviewData(
        name: "Failed to load",
        team: "Check connection",
        position: "--",
        points: "",
      );
    }
    if (isLoading) {
      return _DriverPreviewData(
        name: "Loading...",
        team: "Please wait",
        position: "--",
        points: "",
      );
    }
    final driver = (standings ?? []).isEmpty ? null : standings!.first;
    if (driver == null) {
      return _DriverPreviewData(
        name: "Standings",
        team: "Coming soon",
        position: "--",
        points: "",
      );
    }
    return _DriverPreviewData(
      name: "${driver.givenName} ${driver.familyName}",
      team: driver.teamName,
      position: driver.position,
      points: "${driver.points} pts",
    );
  }

  _TeamPreviewData _teamPreview(
    List<ConstructorStanding>? standings, {
    required bool isLoading,
    required bool hasError,
  }) {
    if (hasError) {
      return _TeamPreviewData(
        name: "Failed to load",
        points: "",
        position: "--",
      );
    }
    if (isLoading) {
      return _TeamPreviewData(
        name: "Loading...",
        points: "",
        position: "--",
      );
    }
    final team = (standings ?? []).isEmpty ? null : standings!.first;
    if (team == null) {
      return _TeamPreviewData(
        name: "Standings",
        points: "",
        position: "--",
      );
    }
    return _TeamPreviewData(
      name: team.teamName,
      points: "${team.points} pts",
      position: team.position,
    );
  }

  List<_PreviewEntry> _driverStandingsPreview(
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
    if (standings == null || standings.isEmpty) {
      return [
        _PreviewEntry(name: "Drivers", points: "Coming soon"),
        _PreviewEntry(name: "TBD", points: ""),
        _PreviewEntry(name: "TBD", points: ""),
      ];
    }
    final top = standings.take(3).toList();
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

  List<_PreviewEntry> _teamStandingsPreview(
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
    if (standings == null || standings.isEmpty) {
      return [
        _PreviewEntry(name: "Teams", points: "Coming soon"),
        _PreviewEntry(name: "TBD", points: ""),
        _PreviewEntry(name: "TBD", points: ""),
      ];
    }
    final top = standings.take(3).toList();
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

  String _teamDriverLines(
    List<DriverStanding>? drivers,
    List<ConstructorStanding>? teams, {
    required bool isLoading,
    required bool hasError,
  }) {
    if (hasError || isLoading) {
      return "-- ---  -- ---";
    }
    final topTeam = (teams ?? []).isEmpty ? null : teams!.first;
    if (topTeam == null || drivers == null) {
      return "-- ---  -- ---";
    }
    final teamDrivers = drivers
        .where((driver) => driver.constructorId == topTeam.constructorId)
        .take(2)
        .toList();
    if (teamDrivers.isEmpty) {
      return "-- ---  -- ---";
    }
    final line1 = _shortDriverLabel(teamDrivers, 0);
    final line2 = _shortDriverLabel(teamDrivers, 1);
    return "$line1  $line2";
  }

  String _shortDriverLabel(List<DriverStanding> drivers, int index) {
    if (index >= drivers.length) {
      return "-- ---";
    }
    final driver = drivers[index];
    final number = driver.permanentNumber ?? '--';
    final code = driver.code?.isNotEmpty == true
        ? driver.code!
        : (driver.familyName.isNotEmpty
            ? driver.familyName.substring(
                0,
                driver.familyName.length >= 3 ? 3 : driver.familyName.length,
              )
            : '---');
    return '${number.toUpperCase()} ${code.toUpperCase()}';
  }

  Widget _buildWidgetCard(
    BuildContext context, {
    required Widget preview,
    required String actionLabel,
    required bool isAdding,
    required VoidCallback? onAction,
    String? statusMessage,
    Widget? option,
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
          if (option != null) ...[
            SizedBox(height: 10),
            option,
          ],
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

Widget _buildTransparencyToggle(
  BuildContext context, {
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  final colors = AppColors.of(context);
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: colors.surfaceAlt,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: colors.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Transparent background',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: colors.f1Red,
        ),
      ],
    ),
  );
}

class _DriverStandingsPreview extends StatelessWidget {
  final String seasonLabel;
  final _DriverPreviewData preview;
  final String title;

  const _DriverStandingsPreview({
    required this.seasonLabel,
    required this.preview,
    required this.title,
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
                        title.toUpperCase(),
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
                  _DriverPreviewRow(preview: preview),
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
  final _TeamPreviewData preview;
  final String driverLines;
  final String title;

  const _TeamStandingsPreview({
    required this.seasonLabel,
    required this.preview,
    required this.driverLines,
    required this.title,
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
                        title.toUpperCase(),
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
                  _TeamPreviewRow(
                    preview: preview,
                    driverLines: driverLines,
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

class _StandingsListPreview extends StatelessWidget {
  final String seasonLabel;
  final String title;
  final String subtitle;
  final List<_PreviewEntry> entries;

  const _StandingsListPreview({
    required this.seasonLabel,
    required this.title,
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
                        title.toUpperCase(),
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
                  SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  SizedBox(height: 8),
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

class _TeamSelection {
  final ConstructorStanding team;
  final List<DriverStanding> drivers;

  const _TeamSelection({
    required this.team,
    required this.drivers,
  });
}

class _SelectionSheet<T> extends StatelessWidget {
  final String title;
  final Future<List<T>> Function() loadItems;
  final Widget Function(BuildContext context, T item) itemBuilder;

  const _SelectionSheet({
    required this.title,
    required this.loadItems,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<T>>(
              future: loadItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: colors.f1Red),
                  );
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return Center(
                    child: Text(
                      'Failed to load',
                      style: TextStyle(color: colors.textMuted),
                    ),
                  );
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(color: colors.textMuted),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(color: colors.border),
                  itemBuilder: (context, index) => itemBuilder(
                    context,
                    items[index],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
class _PreviewEntry {
  final String name;
  final String points;

  const _PreviewEntry({
    required this.name,
    required this.points,
  });
}

class _DriverPreviewData {
  final String name;
  final String team;
  final String position;
  final String points;

  const _DriverPreviewData({
    required this.name,
    required this.team,
    required this.position,
    required this.points,
  });
}

class _TeamPreviewData {
  final String name;
  final String points;
  final String position;

  const _TeamPreviewData({
    required this.name,
    required this.points,
    required this.position,
  });
}

class _DriverPreviewRow extends StatelessWidget {
  final _DriverPreviewData preview;

  const _DriverPreviewRow({required this.preview});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                Icons.person,
                color: colors.textMuted,
                size: 22,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preview.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    preview.team,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surfaceAlt.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Text(
                'P${preview.position}',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
              if (preview.points.isNotEmpty)
                Text(
                  preview.points,
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamPreviewRow extends StatelessWidget {
  final _TeamPreviewData preview;
  final String driverLines;

  const _TeamPreviewRow({
    required this.preview,
    required this.driverLines,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 64,
              height: 36,
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                Icons.directions_car,
                color: colors.textMuted,
                size: 20,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preview.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    preview.points,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surfaceAlt.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Text(
                'P${preview.position}',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
              Text(
                driverLines,
                style: TextStyle(
                  color: onSurface,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
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
