import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../data/api_service.dart';
import '../models/constructor_standing.dart';
import '../models/driver_standing.dart';
import '../models/race.dart';
import '../services/widget_update_service.dart';
import '../services/user_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/team_assets.dart';
import '../utils/country_flags.dart';
import '../widgets/circuit_track.dart';
import '../widgets/empty_state.dart';

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
  bool _favoriteDriverTransparent = false;
  bool _favoriteTeamTransparent = false;
  bool _addingRaceWeekend = false;
  String? _raceWeekendStatusMessage;
  bool _raceWeekendWidgetTransparent = false;
  String? _favoriteDriverId;
  String? _favoriteTeamId;
  late final String _season = DateTime.now().year.toString();
  late final Future<_WidgetPreviewData> _previewFuture;
  _WidgetPreviewData? _previewData;

  @override
  void initState() {
    super.initState();
    _loadFavoriteIds();
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

  Future<void> _loadFavoriteIds() async {
    final driverId = await UserPreferences.getFavoriteDriverId();
    final teamId = await UserPreferences.getFavoriteTeamId();
    if (!mounted) return;
    setState(() {
      _favoriteDriverId = driverId;
      _favoriteTeamId = teamId;
    });
  }

  Future<_WidgetPreviewData> _loadPreviewData() async {
    final api = ApiService();
    final drivers = await api.getDriverStandings(season: _season);
    final teams = await api.getConstructorStandings(season: _season);
    final nextRace = await api.getNextRace(season: _season);
    final raceSchedule = await api.getRaceSchedule(season: _season);
    if (drivers.isEmpty &&
        teams.isEmpty &&
        nextRace == null &&
        raceSchedule.isEmpty) {
      final fallbackSeason = (int.parse(_season) - 1).toString();
      final fallbackDrivers = await api.getDriverStandings(
        season: fallbackSeason,
      );
      final fallbackTeams = await api.getConstructorStandings(
        season: fallbackSeason,
      );
      final fallbackNextRace = await api.getNextRace(season: fallbackSeason);
      final fallbackRaceSchedule = await api.getRaceSchedule(
        season: fallbackSeason,
      );
      if (fallbackDrivers.isNotEmpty ||
          fallbackTeams.isNotEmpty ||
          fallbackNextRace != null ||
          fallbackRaceSchedule.isNotEmpty) {
        return _WidgetPreviewData(
          season: fallbackSeason,
          drivers: fallbackDrivers,
          teams: fallbackTeams,
          nextRace: fallbackNextRace,
          raceSchedule: fallbackRaceSchedule,
        );
      }
    }
    return _WidgetPreviewData(
      season: _season,
      drivers: drivers,
      teams: teams,
      nextRace: nextRace,
      raceSchedule: raceSchedule,
    );
  }

  Future<_WidgetPreviewData> _ensurePreviewData() async {
    final cached = _previewData;
    if (cached != null &&
        (cached.drivers.isNotEmpty ||
            cached.teams.isNotEmpty ||
            cached.nextRace != null ||
            cached.raceSchedule.isNotEmpty)) {
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
    final teamTransparent =
        await WidgetUpdateService.getTeamWidgetTransparent();
    final favoriteDriverTransparent =
        await WidgetUpdateService.getFavoriteDriverDefaultTransparent();
    final favoriteTeamTransparent =
        await WidgetUpdateService.getFavoriteTeamDefaultTransparent();
    if (!mounted) {
      return;
    }
    setState(() {
      _driverWidgetTransparent = driverTransparent;
      _teamWidgetTransparent = teamTransparent;
      _favoriteDriverTransparent = favoriteDriverTransparent;
      _favoriteTeamTransparent = favoriteTeamTransparent;
    });
  }

  bool get _isIosWidgetPickerFlow =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  String get _primaryActionLabel =>
      _isIosWidgetPickerFlow ? 'Prepare widget' : 'Add widget';

  String get _iosWidgetPickerMessage =>
      'Ready. Long-press Home Screen, tap +, then add GridGlance widget.';

  String get _androidUnsupportedMessage =>
      'Widget pinning not supported. Use widget picker.';

  Future<void> _requestPinWidget({
    required String qualifiedAndroidName,
    required ValueSetter<String> onStatus,
  }) async {
    if (_isIosWidgetPickerFlow) {
      onStatus(_iosWidgetPickerMessage);
      return;
    }
    final supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
    if (!supported) {
      onStatus(_androidUnsupportedMessage);
      return;
    }
    await HomeWidget.requestPinWidget(
      qualifiedAndroidName: qualifiedAndroidName,
    );
    onStatus('Widget add request sent');
  }

  Future<void> _addDriverWidget() async {
    setState(() {
      _addingDriver = true;
      _driverStatusMessage = null;
    });

    try {
      final data = await _ensurePreviewData();
      await WidgetUpdateService.updateDriverStandings(
        data.drivers,
        season: data.season,
      );
      await _requestPinWidget(
        qualifiedAndroidName:
            WidgetUpdateService.androidQualifiedDriverWidgetProvider,
        onStatus: (message) {
          if (!mounted) {
            return;
          }
          setState(() {
            _driverStatusMessage = message;
          });
        },
      );
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

  Future<void> _addRaceWeekendWidget() async {
    setState(() {
      _addingRaceWeekend = true;
      _raceWeekendStatusMessage = null;
    });

    try {
      final data = await _ensurePreviewData();
      await WidgetUpdateService.updateRaceWeekend(
        data.raceSchedule,
        nextRace: data.nextRace,
        season: data.season,
      );
      await _requestPinWidget(
        qualifiedAndroidName:
            WidgetUpdateService.androidQualifiedRaceWeekendWidgetProvider,
        onStatus: (message) {
          if (!mounted) {
            return;
          }
          setState(() {
            _raceWeekendStatusMessage = message;
          });
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _raceWeekendStatusMessage = "Failed to request widget";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _addingRaceWeekend = false;
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
      final data = await _ensurePreviewData();
      await WidgetUpdateService.updateTeamStandings(
        data.teams,
        season: data.season,
      );
      await _requestPinWidget(
        qualifiedAndroidName:
            WidgetUpdateService.androidQualifiedTeamWidgetProvider,
        onStatus: (message) {
          if (!mounted) {
            return;
          }
          setState(() {
            _teamStatusMessage = message;
          });
        },
      );
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
    DriverStanding? driver;
    final favoriteDriverId = await UserPreferences.getFavoriteDriverId();
    if (favoriteDriverId != null) {
      final data = await _ensurePreviewData();
      driver = data.drivers.cast<DriverStanding?>().firstWhere(
        (d) => d!.driverId == favoriteDriverId,
        orElse: () => null,
      );
    }
    driver ??= await _pickFavoriteDriver();
    if (driver == null) {
      return;
    }
    try {
      setState(() {
        _addingFavoriteDriver = true;
        _favoriteDriverStatusMessage = null;
      });
      await WidgetUpdateService.setFavoriteDriverDefault(
        driver: driver,
        season: _season,
      );
      await _requestPinWidget(
        qualifiedAndroidName:
            WidgetUpdateService.androidQualifiedFavoriteDriverWidgetProvider,
        onStatus: (message) {
          if (!mounted) {
            return;
          }
          setState(() {
            _favoriteDriverStatusMessage = message;
          });
        },
      );
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
    _TeamSelection? selection;
    final favoriteTeamId = await UserPreferences.getFavoriteTeamId();
    if (favoriteTeamId != null) {
      final data = await _ensurePreviewData();
      final team = data.teams.cast<ConstructorStanding?>().firstWhere(
        (t) => t!.constructorId == favoriteTeamId,
        orElse: () => null,
      );
      if (team != null) {
        final teamDrivers = data.drivers
            .where((d) => d.constructorId == team.constructorId)
            .take(2)
            .toList();
        selection = _TeamSelection(team: team, drivers: teamDrivers);
      }
    }
    selection ??= await _pickFavoriteTeam();
    if (selection == null) {
      return;
    }
    try {
      setState(() {
        _addingFavoriteTeam = true;
        _favoriteTeamStatusMessage = null;
      });
      await WidgetUpdateService.setFavoriteTeamDefault(
        team: selection.team,
        drivers: selection.drivers,
        season: _season,
      );
      await _requestPinWidget(
        qualifiedAndroidName:
            WidgetUpdateService.androidQualifiedFavoriteTeamWidgetProvider,
        onStatus: (message) {
          if (!mounted) {
            return;
          }
          setState(() {
            _favoriteTeamStatusMessage = message;
          });
        },
      );
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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
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
    final colors = AppColors.of(context);
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
          padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // ── Title area ──
            Text(
              "Widgets",
              style: TextStyle(
                color: onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Add live F1 widgets to your home screen',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 16),
            if (_isIosWidgetPickerFlow) ...[
              Container(
                margin: EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.f1Red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.f1Red.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: colors.f1Red),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'iOS uses the widget picker. These buttons prepare live widget data.',
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── ★ FAVORITES ──
            _buildSectionHeader(
              context,
              icon: Icons.star_rounded,
              label: 'Favorites',
              description: 'Track your favorite driver and team',
            ),
            SizedBox(height: 12),
            _buildWidgetCard(
              context,
              title: 'Favorite Driver',
              preview: _DriverStandingsPreview(
                seasonLabel: seasonLabel,
                preview: favoriteDriverPreview,
                title: 'Favorite Driver',
              ),
              transparentValue: _favoriteDriverTransparent,
              onTransparentChanged: (value) async {
                setState(() {
                  _favoriteDriverTransparent = value;
                });
                await WidgetUpdateService.setFavoriteDriverDefaultTransparent(
                  value,
                );
              },
              actionLabel: _primaryActionLabel,
              isAdding: _addingFavoriteDriver,
              onAction: _addingFavoriteDriver ? null : _addFavoriteDriverWidget,
              statusMessage: _favoriteDriverStatusMessage,
            ),
            SizedBox(height: 12),
            _buildWidgetCard(
              context,
              title: 'Favorite Team',
              preview: _TeamStandingsPreview(
                seasonLabel: seasonLabel,
                preview: favoriteTeamPreview,
                driverLines: favoriteTeamDriverLines,
                title: 'Favorite Team',
              ),
              transparentValue: _favoriteTeamTransparent,
              onTransparentChanged: (value) async {
                setState(() {
                  _favoriteTeamTransparent = value;
                });
                await WidgetUpdateService.setFavoriteTeamDefaultTransparent(
                  value,
                );
              },
              actionLabel: _primaryActionLabel,
              isAdding: _addingFavoriteTeam,
              onAction: _addingFavoriteTeam ? null : _addFavoriteTeamWidget,
              statusMessage: _favoriteTeamStatusMessage,
            ),
            SizedBox(height: 24),

            // ── 📊 STANDINGS ──
            _buildSectionHeader(
              context,
              icon: Icons.leaderboard_rounded,
              label: 'Standings',
              description: 'Championship leaderboards at a glance',
            ),
            SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildWidgetCard(
                    context,
                    title: 'Drivers',
                    preview: _StandingsListPreview(
                      seasonLabel: seasonLabel,
                      title: 'Driver Standings',
                      subtitle: 'Top 3 drivers',
                      entries: driverStandings,
                    ),
                    transparentValue: _driverWidgetTransparent,
                    onTransparentChanged: (value) async {
                      setState(() {
                        _driverWidgetTransparent = value;
                      });
                      await WidgetUpdateService.setDriverWidgetTransparent(
                        value,
                      );
                    },
                    actionLabel: _primaryActionLabel,
                    isAdding: _addingDriver,
                    onAction: _addingDriver ? null : _addDriverWidget,
                    statusMessage: _driverStatusMessage,
                    compact: true,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildWidgetCard(
                    context,
                    title: 'Teams',
                    preview: _StandingsListPreview(
                      seasonLabel: seasonLabel,
                      title: 'Team Standings',
                      subtitle: 'Top 3 teams',
                      entries: teamStandings,
                    ),
                    transparentValue: _teamWidgetTransparent,
                    onTransparentChanged: (value) async {
                      setState(() {
                        _teamWidgetTransparent = value;
                      });
                      await WidgetUpdateService.setTeamWidgetTransparent(value);
                    },
                    actionLabel: _primaryActionLabel,
                    isAdding: _addingTeam,
                    onAction: _addingTeam ? null : _addTeamWidget,
                    statusMessage: _teamStatusMessage,
                    compact: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            // ── 🏁 RACE ──
            _buildSectionHeader(
              context,
              icon: Icons.flag_rounded,
              label: 'Race Weekend',
              description: 'Upcoming sessions and countdown',
            ),
            SizedBox(height: 12),
            _buildWidgetCard(
              context,
              title: 'Race Weekend',
              preview: _RaceWeekendPreview(
                seasonLabel: seasonLabel,
                race: data?.nextRace,
                raceSchedule: data?.raceSchedule,
                isLoading: isLoading,
                hasError: hasError,
              ),
              transparentValue: _raceWeekendWidgetTransparent,
              onTransparentChanged: (value) async {
                setState(() {
                  _raceWeekendWidgetTransparent = value;
                });
                await WidgetUpdateService.setRaceWeekendWidgetTransparent(
                  value,
                );
              },
              actionLabel: _primaryActionLabel,
              isAdding: _addingRaceWeekend,
              onAction: _addingRaceWeekend ? null : _addRaceWeekendWidget,
              statusMessage: _raceWeekendStatusMessage,
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
    DriverStanding? driver;
    if (_favoriteDriverId != null &&
        _favoriteDriverId!.isNotEmpty &&
        standings != null) {
      driver = standings.cast<DriverStanding?>().firstWhere(
        (d) => d!.driverId == _favoriteDriverId,
        orElse: () => null,
      );
    }
    driver ??= (standings ?? []).isEmpty ? null : standings!.first;
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
      return _TeamPreviewData(name: "Loading...", points: "", position: "--");
    }
    ConstructorStanding? team;
    if (_favoriteTeamId != null &&
        _favoriteTeamId!.isNotEmpty &&
        standings != null) {
      team = standings.cast<ConstructorStanding?>().firstWhere(
        (t) => t!.constructorId == _favoriteTeamId,
        orElse: () => null,
      );
    }
    team ??= (standings ?? []).isEmpty ? null : standings!.first;
    if (team == null) {
      return _TeamPreviewData(name: "Standings", points: "", position: "--");
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
    return List.generate(3, (index) {
      if (index >= top.length) {
        return _PreviewEntry(name: "TBD", points: "");
      }
      final driver = top[index];
      return _PreviewEntry(
        name: "${driver.givenName} ${driver.familyName}",
        points: "${driver.points} pts",
      );
    });
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
    return List.generate(3, (index) {
      if (index >= top.length) {
        return _PreviewEntry(name: "TBD", points: "");
      }
      final team = top[index];
      return _PreviewEntry(name: team.teamName, points: "${team.points} pts");
    });
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
    ConstructorStanding? topTeam;
    if (_favoriteTeamId != null &&
        _favoriteTeamId!.isNotEmpty &&
        teams != null) {
      topTeam = teams.cast<ConstructorStanding?>().firstWhere(
            (t) => t!.constructorId == _favoriteTeamId,
            orElse: () => null,
          );
    }
    topTeam ??= (teams ?? []).isEmpty ? null : teams!.first;
    if (topTeam == null || drivers == null) {
      return "-- ---  -- ---";
    }
    final teamDrivers = drivers
        .where((driver) => driver.constructorId == topTeam!.constructorId)
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

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description,
  }) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colors.f1Red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: colors.f1Red),
            ),
            SizedBox(width: 10),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Padding(
          padding: EdgeInsets.only(left: 38),
          child: Text(
            description,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWidgetCard(
    BuildContext context, {
    required String title,
    required Widget preview,
    required bool transparentValue,
    required ValueChanged<bool> onTransparentChanged,
    required String actionLabel,
    required bool isAdding,
    required VoidCallback? onAction,
    String? statusMessage,
    bool compact = false,
  }) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview
          ClipRRect(borderRadius: BorderRadius.circular(12), child: preview),
          SizedBox(height: compact ? 8 : 12),
          // Controls row
          Row(
            children: [
              // Transparency chip
              GestureDetector(
                onTap: () => onTransparentChanged(!transparentValue),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: transparentValue
                        ? colors.f1Red.withValues(alpha: 0.1)
                        : colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: transparentValue
                          ? colors.f1Red.withValues(alpha: 0.3)
                          : colors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        transparentValue
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 12,
                        color: transparentValue
                            ? colors.f1Red
                            : colors.textMuted,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'BG',
                        style: TextStyle(
                          color: transparentValue
                              ? colors.f1Red
                              : colors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              // Add button
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.f1Red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: onAction,
                    icon: Icon(isAdding ? null : Icons.add_rounded, size: 16),
                    label: Text(
                      isAdding ? "Adding..." : actionLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (statusMessage != null) ...[
            SizedBox(height: 8),
            Text(
              statusMessage,
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
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
            colors: [colors.backgroundAlt, colors.surface],
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
                      Flexible(
                        child: Text(
                          title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
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
                  Expanded(child: _DriverPreviewRow(preview: preview)),
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
            colors: [colors.backgroundAlt, colors.surface],
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
                      colors.f1RedBright.withValues(
                        alpha: isDark ? 0.28 : 0.15,
                      ),
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
                      Flexible(
                        child: Text(
                          title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
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
                  Expanded(
                    child: _TeamPreviewRow(
                      preview: preview,
                      driverLines: driverLines,
                    ),
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

class _RaceWeekendPreview extends StatelessWidget {
  final String seasonLabel;
  final Race? race;
  final List<Race>? raceSchedule;
  final bool isLoading;
  final bool hasError;

  const _RaceWeekendPreview({
    required this.seasonLabel,
    required this.race,
    required this.raceSchedule,
    required this.isLoading,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;

    final raceName = _raceName;
    final location = _location;
    final sessionLines = _sessionLines;
    final countdownLine = _countdownLine;
    final nextIndex = _nextSessionIndex;

    return AspectRatio(
      aspectRatio: 16 / 14,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.backgroundAlt, colors.surface],
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
                      colors.f1RedBright.withValues(
                        alpha: isDark ? 0.28 : 0.15,
                      ),
                      colors.f1Red.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
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
                      Flexible(
                        child: Text(
                          'RACE WEEKEND',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
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
                  // Race name + track
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (race != null) ...[
                                  Text(
                                    countryFlag(race!.country),
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Text(
                                    raceName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: onSurface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 2),
                            Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (race != null && race!.circuitId.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: CircuitTrack(
                            circuitId: race!.circuitId,
                            width: 52,
                            height: 36,
                            color: colors.f1RedBright.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Countdown
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      countdownLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  // Session list
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(sessionLines.length, (i) {
                        final isNext = i == nextIndex;
                        return Padding(
                          padding: EdgeInsets.only(top: i == 0 ? 0 : 3),
                          child: Row(
                            children: [
                              if (isNext)
                                Container(
                                  width: 3,
                                  height: 10,
                                  margin: EdgeInsets.only(right: 5),
                                  decoration: BoxDecoration(
                                    color: colors.f1Red,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  sessionLines[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isNext
                                        ? onSurface
                                        : colors.textMuted,
                                    fontSize: 10,
                                    fontWeight: isNext
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _raceName {
    if (hasError) return 'Failed to load';
    if (isLoading) return 'Loading...';
    if (race == null) return 'No upcoming race';
    return race!.raceName.isEmpty ? 'Race weekend' : race!.raceName;
  }

  String get _location {
    if (hasError) return 'Check connection';
    if (isLoading) return 'Please wait';
    if (race == null) return 'Season complete';
    return race!.location.isEmpty
        ? (race!.circuitName.isEmpty ? 'Location TBA' : race!.circuitName)
        : race!.location;
  }

  String get _countdownLine {
    if (hasError) return 'Retry from app';
    if (isLoading) return 'Calculating...';
    if (race == null) return 'Awaiting next calendar';
    final sessions = race!.sessions;
    final now = DateTime.now();
    for (final session in sessions) {
      final start = session.startDateTime;
      if (start != null && start.isAfter(now)) {
        final remaining = start.difference(now);
        final label = _shortCountdown(remaining);
        return '${session.name} \u2022 $label';
      }
    }
    return 'Weekend in progress';
  }

  List<String> get _sessionLines {
    if (race == null) return [];
    return race!.sessions.map((s) {
      final dt = s.startDateTime;
      if (dt == null) return s.name;
      final local = dt.toLocal();
      final month = _monthAbbr(local.month);
      final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      final meridiem = local.hour >= 12 ? 'PM' : 'AM';
      final dayName = _dayAbbr(local.weekday);
      return '${s.name} \u2022 $dayName $month ${local.day} \u2022 $hour:$minute $meridiem';
    }).toList();
  }

  int get _nextSessionIndex {
    if (race == null) return -1;
    final now = DateTime.now();
    final sessions = race!.sessions;
    for (int i = 0; i < sessions.length; i++) {
      final start = sessions[i].startDateTime;
      if (start != null && start.isAfter(now)) return i;
    }
    return -1;
  }

  static String _shortCountdown(Duration d) {
    if (d.inDays > 0) return 'Starts in ${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return 'Starts in ${d.inHours}h ${d.inMinutes % 60}m';
    return 'Starts in ${d.inMinutes}m';
  }

  static String _monthAbbr(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return (m >= 1 && m <= 12) ? months[m - 1] : '---';
  }

  static String _dayAbbr(int wd) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return (wd >= 1 && wd <= 7) ? days[wd - 1] : '---';
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
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.backgroundAlt, colors.surface],
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
                      colors.f1RedBright.withValues(
                        alpha: isDark ? 0.28 : 0.15,
                      ),
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
              padding: EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
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
                      Flexible(
                        child: Text(
                          title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
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
                  SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(color: colors.textMuted, fontSize: 11),
                  ),
                  SizedBox(height: 8),
                  // Podium section
                  Expanded(child: _buildPodium(context, colors, onSurface)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodium(BuildContext context, AppColors colors, Color onSurface) {
    final second = entries.length > 1 ? entries[1] : null;
    final first = entries.isNotEmpty ? entries[0] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return Column(
      children: [
        // Names & points row: 2nd · 1st (raised) · 3rd
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: second != null
                    ? _podiumLabel(second, 2, colors, onSurface)
                    : SizedBox.shrink(),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: first != null
                      ? _podiumLabel(first, 1, colors, onSurface)
                      : SizedBox.shrink(),
                ),
              ),
              Expanded(
                child: third != null
                    ? _podiumLabel(third, 3, colors, onSurface)
                    : SizedBox.shrink(),
              ),
            ],
          ),
        ),
        SizedBox(height: 2),
        // Podium blocks
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _podiumBlock(2, colors, height: 24)),
            Expanded(child: _podiumBlock(1, colors, height: 34)),
            Expanded(child: _podiumBlock(3, colors, height: 16)),
          ],
        ),
      ],
    );
  }

  Widget _podiumLabel(
    _PreviewEntry entry,
    int position,
    AppColors colors,
    Color onSurface,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Position badge
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: position == 1
                ? colors.f1Red.withValues(alpha: 0.95)
                : colors.surfaceAlt,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$position',
            style: TextStyle(
              color: position == 1 ? Colors.white : colors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(height: 4),
        // Name
        Text(
          entry.name.split(' ').last.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: onSurface,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 2),
        // Points
        if (entry.points.isNotEmpty)
          Text(
            entry.points,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _podiumBlock(
    int position,
    AppColors colors, {
    required double height,
  }) {
    final positionColors = {
      1: colors.f1Red,
      2: colors.textMuted,
      3: Color(0xFFCD7F32),
    };
    final blockColor = positionColors[position] ?? colors.surfaceAlt;

    return Container(
      height: height,
      margin: EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            blockColor.withValues(alpha: 0.4),
            blockColor.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
        border: Border.all(color: blockColor.withValues(alpha: 0.3)),
      ),
      alignment: Alignment.center,
      child: Text(
        '$position',
        style: TextStyle(
          color: blockColor,
          fontSize: height * 0.4,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WidgetPreviewData {
  final String season;
  final List<DriverStanding> drivers;
  final List<ConstructorStanding> teams;
  final Race? nextRace;
  final List<Race> raceSchedule;

  const _WidgetPreviewData({
    required this.season,
    required this.drivers,
    required this.teams,
    required this.nextRace,
    required this.raceSchedule,
  });
}

class _TeamSelection {
  final ConstructorStanding team;
  final List<DriverStanding> drivers;

  const _TeamSelection({required this.team, required this.drivers});
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
                    child: EmptyState(
                      message: 'Failed to load',
                      type: EmptyStateType.network,
                    ),
                  );
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return Center(
                    child: EmptyState(
                      message: 'No data available',
                      type: EmptyStateType.generic,
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => Divider(color: colors.border),
                  itemBuilder: (context, index) =>
                      itemBuilder(context, items[index]),
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

  const _PreviewEntry({required this.name, required this.points});
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
              child: Icon(Icons.person, color: colors.textMuted, size: 22),
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
                    style: TextStyle(color: colors.textMuted, fontSize: 11),
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

  const _TeamPreviewRow({required this.preview, required this.driverLines});

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
              child: Center(
                child: IconTheme(
                  data: IconThemeData(color: colors.textMuted),
                  child: teamLogoOrIcon(preview.name, size: 20),
                ),
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
                    style: TextStyle(color: colors.textMuted, fontSize: 11),
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
