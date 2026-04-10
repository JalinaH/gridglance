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
import '../services/f1_image_service.dart';
import '../utils/team_colors.dart';
import '../widgets/car_image.dart';
import '../widgets/circuit_track.dart';
import '../widgets/driver_photo.dart';
import '../widgets/adaptive_layout.dart';
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
        final favoriteTeamDrivers = _teamDriversData(
          data?.drivers,
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

        final wide = isWideScreen(context);

        // ── Reusable widget card builders ──
        final favDriverCard = _buildWidgetCard(
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
        );

        final favTeamCard = _buildWidgetCard(
          context,
          title: 'Favorite Team',
          preview: _TeamStandingsPreview(
            seasonLabel: seasonLabel,
            preview: favoriteTeamPreview,
            driverLines: favoriteTeamDriverLines,
            drivers: favoriteTeamDrivers,
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
        );

        final driverStandingsCard = _buildWidgetCard(
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
            await WidgetUpdateService.setDriverWidgetTransparent(value);
          },
          actionLabel: _primaryActionLabel,
          isAdding: _addingDriver,
          onAction: _addingDriver ? null : _addDriverWidget,
          statusMessage: _driverStatusMessage,
          compact: true,
        );

        final teamStandingsCard = _buildWidgetCard(
          context,
          title: 'Teams',
          preview: _StandingsListPreview(
            seasonLabel: seasonLabel,
            title: 'Team Standings',
            subtitle: 'Top 3 teams',
            entries: teamStandings,
            isTeam: true,
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
        );

        final raceWeekendCard = _buildWidgetCard(
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
            await WidgetUpdateService.setRaceWeekendWidgetTransparent(value);
          },
          actionLabel: _primaryActionLabel,
          isAdding: _addingRaceWeekend,
          onAction: _addingRaceWeekend ? null : _addRaceWeekendWidget,
          statusMessage: _raceWeekendStatusMessage,
        );

        // ── Header widgets (shared between layouts) ──
        final headerWidgets = <Widget>[
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
        ];

        return ListView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            ...headerWidgets,

            if (wide) ...[
              // ── TABLET LAYOUT: 2-column grid ──

              // Favorites row
              _buildSectionHeader(
                context,
                icon: Icons.star_rounded,
                label: 'Favorites',
                description: 'Track your favorite driver and team',
              ),
              SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: favDriverCard),
                  SizedBox(width: 16),
                  Expanded(child: favTeamCard),
                ],
              ),
              SizedBox(height: 24),

              // Standings + Race Weekend row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Standings column (left)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          context,
                          icon: Icons.leaderboard_rounded,
                          label: 'Standings',
                          description: 'Championship leaderboards',
                        ),
                        SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: driverStandingsCard),
                            SizedBox(width: 12),
                            Expanded(child: teamStandingsCard),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  // Race Weekend column (right)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          context,
                          icon: Icons.flag_rounded,
                          label: 'Race Weekend',
                          description: 'Upcoming sessions and countdown',
                        ),
                        SizedBox(height: 12),
                        raceWeekendCard,
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              // ── MOBILE LAYOUT: single column ──

              // Favorites
              _buildSectionHeader(
                context,
                icon: Icons.star_rounded,
                label: 'Favorites',
                description: 'Track your favorite driver and team',
              ),
              SizedBox(height: 12),
              favDriverCard,
              SizedBox(height: 12),
              favTeamCard,
              SizedBox(height: 24),

              // Standings
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
                  Expanded(child: driverStandingsCard),
                  SizedBox(width: 12),
                  Expanded(child: teamStandingsCard),
                ],
              ),
              SizedBox(height: 24),

              // Race Weekend
              _buildSectionHeader(
                context,
                icon: Icons.flag_rounded,
                label: 'Race Weekend',
                description: 'Upcoming sessions and countdown',
              ),
              SizedBox(height: 12),
              raceWeekendCard,
            ],
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
        familyName: '',
        team: "Check connection",
        position: "--",
        points: "",
        driverNumber: '--',
        driverCode: '---',
        driverId: '',
        constructorId: '',
      );
    }
    if (isLoading) {
      return _DriverPreviewData(
        name: "Loading...",
        familyName: '',
        team: "Please wait",
        position: "--",
        points: "",
        driverNumber: '--',
        driverCode: '---',
        driverId: '',
        constructorId: '',
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
        familyName: '',
        team: "Coming soon",
        position: "--",
        points: "",
        driverNumber: '--',
        driverCode: '---',
        driverId: '',
        constructorId: '',
      );
    }
    return _DriverPreviewData(
      name: "${driver.givenName} ${driver.familyName}",
      familyName: driver.familyName,
      team: driver.teamName,
      position: driver.position,
      points: "${driver.points} pts",
      driverNumber: driver.permanentNumber ?? '--',
      driverCode:
          driver.code ?? driver.familyName.substring(0, 3).toUpperCase(),
      driverId: driver.driverId,
      constructorId: driver.constructorId,
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
        constructorId: '',
      );
    }
    if (isLoading) {
      return _TeamPreviewData(
        name: "Loading...",
        points: "",
        position: "--",
        constructorId: '',
      );
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
      return _TeamPreviewData(
        name: "Standings",
        points: "",
        position: "--",
        constructorId: '',
      );
    }
    return _TeamPreviewData(
      name: team.teamName,
      points: "${team.points} pts",
      position: team.position,
      constructorId: team.constructorId,
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
        driverId: driver.driverId,
        permanentNumber: driver.permanentNumber,
        code: driver.code,
        teamName: driver.teamName,
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
      return _PreviewEntry(
        name: team.teamName,
        points: "${team.points} pts",
        teamName: team.teamName,
        constructorId: team.constructorId,
      );
    });
  }

  List<_TeamDriverData> _teamDriversData(
    List<DriverStanding>? drivers,
    List<ConstructorStanding>? teams, {
    required bool isLoading,
    required bool hasError,
  }) {
    if (hasError || isLoading || drivers == null) {
      return [];
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
    if (topTeam == null) return [];
    return drivers
        .where((d) => d.constructorId == topTeam!.constructorId)
        .take(2)
        .map(
          (d) => _TeamDriverData(
            number: d.permanentNumber ?? '--',
            familyName: d.familyName,
            code: d.code ?? d.familyName.substring(0, 3).toUpperCase(),
            driverId: d.driverId,
          ),
        )
        .toList();
  }

  String _teamDriverLines(
    List<DriverStanding>? drivers,
    List<ConstructorStanding>? teams, {
    required bool isLoading,
    required bool hasError,
  }) {
    final data = _teamDriversData(
      drivers,
      teams,
      isLoading: isLoading,
      hasError: hasError,
    );
    if (data.isEmpty) return "-- ---  -- ---";
    final line1 = '${data[0].number} ${data[0].code.toUpperCase()}';
    final line2 = data.length > 1
        ? '${data[1].number} ${data[1].code.toUpperCase()}'
        : '-- ---';
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

  // Widget-style dark colors (always dark to match actual Android widget)
  static const _bg = Color(0xFF121722);
  static const _bgAlt = Color(0xFF151B24);
  static const _surfaceAlt = Color(0xFF1C2430);
  static const _border = Color(0xFF232C3A);
  static const _textPrimary = Color(0xFFF7F8FA);
  static const _textMuted = Color(0xFF9EA7B5);
  static const _red = Color(0xFFE10600);
  @override
  Widget build(BuildContext context) {
    final tColor = preview.constructorId.isNotEmpty
        ? teamColor(preview.team)
        : _red;
    return AspectRatio(
      aspectRatio: 18 / 10,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bg, _bgAlt],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Top half: driver photo + overlay
            Expanded(
              child: Stack(
                children: [
                  // Driver photo background (rectangular, like Android widget)
                  Positioned.fill(
                    child: _DriverPhotoRect(
                      driverId: preview.driverId,
                      permanentNumber: preview.driverNumber != '--'
                          ? preview.driverNumber
                          : null,
                      code: preview.driverCode != '---'
                          ? preview.driverCode
                          : null,
                      teamName: preview.team,
                      initials: preview.name.isNotEmpty ? preview.name[0] : '?',
                    ),
                  ),
                  // Number badge + last name + season overlay
                  Positioned(
                    left: 10,
                    top: 8,
                    right: 10,
                    child: Row(
                      children: [
                        // Driver number badge
                        Container(
                          width: 28,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            preview.driverNumber,
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            preview.familyName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _seasonPill(seasonLabel),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bottom half: team accent bar + details
            Expanded(
              child: Row(
                children: [
                  // Team color accent bar
                  Container(width: 4, color: tColor),
                  // Details
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            preview.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            preview.team,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _textMuted, fontSize: 9),
                          ),
                          SizedBox(height: 6),
                          // Stats row: Position + Points
                          Row(
                            children: [
                              Expanded(
                                child: _statBox([
                                  TextSpan(
                                    text: 'P',
                                    style: TextStyle(
                                      color: _textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  TextSpan(
                                    text: preview.position,
                                    style: TextStyle(
                                      color: _textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ]),
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: _statBox([
                                  TextSpan(
                                    text: preview.points.replaceAll(' pts', ''),
                                    style: TextStyle(
                                      color: _textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' PTS',
                                    style: TextStyle(
                                      color: _textMuted,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ]),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  static Widget _seasonPill(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _textMuted,
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Widget _statBox(List<TextSpan> spans) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: RichText(text: TextSpan(children: spans)),
    );
  }
}

class _TeamStandingsPreview extends StatelessWidget {
  final String seasonLabel;
  final _TeamPreviewData preview;
  final String driverLines;
  final List<_TeamDriverData> drivers;
  final String title;

  const _TeamStandingsPreview({
    required this.seasonLabel,
    required this.preview,
    required this.driverLines,
    required this.drivers,
    required this.title,
  });

  static const _bg = Color(0xFF121722);
  static const _bgAlt = Color(0xFF151B24);
  static const _surfaceAlt = Color(0xFF1C2430);
  static const _border = Color(0xFF232C3A);
  static const _textPrimary = Color(0xFFF7F8FA);
  static const _textMuted = Color(0xFF9EA7B5);

  @override
  Widget build(BuildContext context) {
    final tColor = preview.constructorId.isNotEmpty
        ? teamColor(preview.name)
        : const Color(0xFFE10600);
    return AspectRatio(
      aspectRatio: 18 / 10,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bg, _bgAlt],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Top half: car image + team name overlay
            Expanded(
              child: Stack(
                children: [
                  if (preview.constructorId.isNotEmpty)
                    Positioned.fill(
                      child: CarImage(
                        teamName: preview.name,
                        constructorId: preview.constructorId,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    )
                  else
                    Positioned.fill(child: Container(color: _surfaceAlt)),
                  // Team name + season overlay
                  Positioned(
                    left: 10,
                    top: 8,
                    right: 10,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _DriverStandingsPreview._seasonPill(seasonLabel),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bottom half: accent bar + driver rows + stats
            Expanded(
              child: Row(
                children: [
                  Container(width: 4, color: tColor),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Driver rows
                          for (int i = 0; i < 2; i++) ...[
                            if (i > 0) SizedBox(height: 4),
                            _driverRow(
                              i < drivers.length ? drivers[i] : null,
                              tColor,
                            ),
                          ],
                          SizedBox(height: 5),
                          // Stats row
                          Row(
                            children: [
                              Expanded(
                                child: _DriverStandingsPreview._statBox([
                                  TextSpan(
                                    text: 'P',
                                    style: TextStyle(
                                      color: _textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  TextSpan(
                                    text: preview.position,
                                    style: TextStyle(
                                      color: _textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ]),
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: _DriverStandingsPreview._statBox([
                                  TextSpan(
                                    text: preview.points.replaceAll(' pts', ''),
                                    style: TextStyle(
                                      color: _textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' PTS',
                                    style: TextStyle(
                                      color: _textMuted,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ]),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  Widget _driverRow(_TeamDriverData? driver, Color tColor) {
    final number = driver?.number ?? '--';
    final name = driver?.familyName.toUpperCase() ?? '---';
    final code = driver?.code.toUpperCase() ?? '---';
    return Row(
      children: [
        // Number badge
        Container(
          width: 26,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            number,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
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
              color: _textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        Text(
          code,
          style: TextStyle(
            color: _textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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

  static const _bg = Color(0xFF121722);
  static const _bgAlt = Color(0xFF151B24);
  static const _surfaceAlt = Color(0xFF1C2430);
  static const _border = Color(0xFF232C3A);
  static const _textPrimary = Color(0xFFF7F8FA);
  static const _textMuted = Color(0xFF9EA7B5);
  static const _red = Color(0xFFE10600);
  static const _redBright = Color(0xFFFF3B30);

  @override
  Widget build(BuildContext context) {
    final raceName = _raceName;
    final location = _location;
    final sessionLines = _sessionLines;
    final countdownLine = _countdownLine;
    final nextIndex = _nextSessionIndex;
    final roundLabel = race != null ? 'R${race!.round}' : '';

    return AspectRatio(
      aspectRatio: 16 / 14,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bg, _bgAlt],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top: race info (left) + track (right)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            Container(
                              height: 3,
                              width: 36,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_red, _redBright],
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
                                  color: _textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            SizedBox(width: 6),
                            if (roundLabel.isNotEmpty)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  roundLabel,
                                  style: TextStyle(
                                    color: _red,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 6),
                        // Race name
                        Text(
                          raceName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  // Track layout image
                  if (race != null && race!.circuitId.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Opacity(
                        opacity: 0.6,
                        child: CircuitTrack(
                          circuitId: race!.circuitId,
                          width: 64,
                          height: 48,
                          color: _textMuted.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 8),
              // Countdown row
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    // Active dot
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [_red, _redBright]),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        countdownLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 6),
              // Session timeline
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(sessionLines.length, (i) {
                    final isNext = i == nextIndex;
                    return Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 2),
                      child: Row(
                        children: [
                          // Timeline dot
                          Container(
                            width: isNext ? 7 : 6,
                            height: isNext ? 7 : 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isNext
                                  ? null
                                  : _textMuted.withValues(alpha: 0.4),
                              gradient: isNext
                                  ? LinearGradient(colors: [_red, _redBright])
                                  : null,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sessionLines[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isNext ? _textPrimary : _textMuted,
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
  final bool isTeam;

  const _StandingsListPreview({
    required this.seasonLabel,
    required this.title,
    required this.subtitle,
    required this.entries,
    this.isTeam = false,
  });

  static const _bg = Color(0xFF121722);
  static const _bgAlt = Color(0xFF151B24);
  static const _surfaceAlt = Color(0xFF1C2430);
  static const _border = Color(0xFF232C3A);
  static const _textPrimary = Color(0xFFF7F8FA);
  static const _textSecondary = Color(0xFFDCE1EA);
  static const _textMuted = Color(0xFF9EA7B5);
  static const _red = Color(0xFFE10600);
  static const _redBright = Color(0xFFFF3B30);
  static const _bronze = Color(0xFFCD7F32);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bg, _bgAlt],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    height: 3,
                    width: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_red, _redBright]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  _DriverStandingsPreview._seasonPill(seasonLabel),
                ],
              ),
              SizedBox(height: 8),
              // Podium section
              Expanded(child: _buildPodium()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodium() {
    final second = entries.length > 1 ? entries[1] : null;
    final first = entries.isNotEmpty ? entries[0] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: second != null
                    ? _podiumColumn(second, 2)
                    : SizedBox.shrink(),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: first != null
                      ? _podiumColumn(first, 1)
                      : SizedBox.shrink(),
                ),
              ),
              Expanded(
                child: third != null
                    ? _podiumColumn(third, 3)
                    : SizedBox.shrink(),
              ),
            ],
          ),
        ),
        SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _podiumBlock(2, height: 24)),
            Expanded(child: _podiumBlock(1, height: 34)),
            Expanded(child: _podiumBlock(3, height: 16)),
          ],
        ),
      ],
    );
  }

  Widget _podiumColumn(_PreviewEntry entry, int position) {
    final isP1 = position == 1;
    final photoSize = isP1 ? 36.0 : 30.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Photo / logo
        if (isTeam)
          _teamLogo(entry, photoSize)
        else
          _driverAvatar(entry, photoSize, isP1),
        SizedBox(height: 3),
        // Name
        Text(
          entry.name.split(' ').last.toUpperCase(),
          maxLines: isTeam ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isP1 ? _textPrimary : _textSecondary,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 1),
        if (entry.points.isNotEmpty)
          Text(
            entry.points,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isP1 ? _textSecondary : _textMuted,
              fontSize: 7,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _driverAvatar(_PreviewEntry entry, double size, bool isP1) {
    if (entry.driverId != null && entry.driverId!.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: DriverPhoto(
          driverId: entry.driverId!,
          permanentNumber: entry.permanentNumber,
          code: entry.code,
          teamName: entry.teamName ?? '',
          initials: entry.name.isNotEmpty ? entry.name[0] : '?',
          size: size,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _surfaceAlt,
        border: Border.all(color: isP1 ? _red.withValues(alpha: 0.5) : _border),
      ),
      child: Icon(Icons.person, color: _textMuted, size: size * 0.5),
    );
  }

  Widget _teamLogo(_PreviewEntry entry, double size) {
    if (entry.teamName != null && entry.teamName!.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: teamLogoOrIcon(entry.teamName!, size: size * 0.7),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _surfaceAlt),
      child: Icon(Icons.directions_car, color: _textMuted, size: size * 0.5),
    );
  }

  Widget _podiumBlock(int position, {required double height}) {
    final positionColors = {1: _red, 2: _textMuted, 3: _bronze};
    final blockColor = positionColors[position] ?? _surfaceAlt;

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
  final String? driverId;
  final String? permanentNumber;
  final String? code;
  final String? teamName;
  final String? constructorId;

  const _PreviewEntry({
    required this.name,
    required this.points,
    this.driverId,
    this.permanentNumber,
    this.code,
    this.teamName,
    this.constructorId,
  });
}

class _DriverPreviewData {
  final String name;
  final String familyName;
  final String team;
  final String position;
  final String points;
  final String driverNumber;
  final String driverCode;
  final String driverId;
  final String constructorId;

  const _DriverPreviewData({
    required this.name,
    required this.familyName,
    required this.team,
    required this.position,
    required this.points,
    required this.driverNumber,
    required this.driverCode,
    required this.driverId,
    required this.constructorId,
  });
}

class _TeamPreviewData {
  final String name;
  final String points;
  final String position;
  final String constructorId;

  const _TeamPreviewData({
    required this.name,
    required this.points,
    required this.position,
    required this.constructorId,
  });
}

class _TeamDriverData {
  final String number;
  final String familyName;
  final String code;
  final String driverId;

  const _TeamDriverData({
    required this.number,
    required this.familyName,
    required this.code,
    required this.driverId,
  });
}

/// Rectangular driver photo for the favourite-driver widget preview.
/// Matches the Android widget's ImageView (scaleType=fitCenter) layout.
class _DriverPhotoRect extends StatelessWidget {
  final String driverId;
  final String? permanentNumber;
  final String? code;
  final String teamName;
  final String initials;

  const _DriverPhotoRect({
    required this.driverId,
    this.permanentNumber,
    this.code,
    required this.teamName,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final color = teamColor(teamName);
    final url = F1ImageService.instance.driverHeadshotUrl(
      permanentNumber: permanentNumber,
      code: code,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.18), const Color(0xFF1C2430)],
        ),
      ),
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              errorBuilder: (_, _, _) => _placeholder(color),
            )
          : _placeholder(color),
    );
  }

  Widget _placeholder(Color color) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: color.withValues(alpha: 0.5),
          fontSize: 32,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
