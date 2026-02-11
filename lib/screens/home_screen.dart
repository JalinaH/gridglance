import 'dart:math';
import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../models/constructor_standing.dart';
import '../models/driver_standing.dart';
import '../models/race.dart';
import '../models/season_overview.dart';
import '../services/user_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/date_time_format.dart';
import '../widgets/countdown_text.dart';
import '../widgets/f1_scaffold.dart';
import '../widgets/reveal.dart';
import '../widgets/season_cards.dart';
import '../widgets/team_logo.dart';
import '../services/widget_update_service.dart';
import 'compare_mode_screen.dart';
import 'constructor_standings_screen.dart';
import 'driver_standings_screen.dart';
import 'last_race_results_screen.dart';
import 'race_schedule_screen.dart';
import 'race_weekend_center_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final bool showAppBar;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.showAppBar = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _season = DateTime.now().year.toString();
  late Future<SeasonOverview> _overview;
  bool _didUpdateWidget = false;
  String? _favoriteDriverId;
  String? _favoriteTeamId;

  @override
  void initState() {
    super.initState();
    _overview = ApiService().getSeasonOverview(season: _season);
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final storedSeason = await UserPreferences.getSeason();
    final favoriteDriverId = await UserPreferences.getFavoriteDriverId();
    final favoriteTeamId = await UserPreferences.getFavoriteTeamId();
    if (!mounted) {
      return;
    }
    setState(() {
      _favoriteDriverId = favoriteDriverId;
      _favoriteTeamId = favoriteTeamId;
      if (storedSeason != null &&
          storedSeason.isNotEmpty &&
          storedSeason != _season) {
        _season = storedSeason;
        _overview = ApiService().getSeasonOverview(season: _season);
        _didUpdateWidget = false;
      }
    });
  }

  void _refresh() {
    setState(() {
      _overview = ApiService().getSeasonOverview(season: _season);
      _didUpdateWidget = false;
    });
  }

  List<String> _seasonOptions() {
    const firstSeason = 1950;
    final currentYear = DateTime.now().year;
    return List.generate(
      currentYear - firstSeason + 1,
      (index) => (currentYear - index).toString(),
    );
  }

  Future<void> _selectSeason() async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) {
        final colors = AppColors.of(context);
        final seasons = _seasonOptions();
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
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
                        'Select Season',
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
                child: ListView.separated(
                  itemCount: seasons.length,
                  separatorBuilder: (_, _) => Divider(color: colors.border),
                  itemBuilder: (context, index) {
                    final season = seasons[index];
                    return ListTile(
                      title: Text(
                        season,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: season == _season
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      trailing: season == _season
                          ? Icon(Icons.check, color: colors.f1Red)
                          : null,
                      onTap: () => Navigator.of(context).pop(season),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selection == null || selection == _season) {
      return;
    }
    await UserPreferences.setSeason(selection);
    if (!mounted) {
      return;
    }
    setState(() {
      _season = selection;
      _overview = ApiService().getSeasonOverview(season: _season);
      _didUpdateWidget = false;
    });
  }

  DriverStanding? _findFavoriteDriver(List<DriverStanding> drivers) {
    final id = _favoriteDriverId;
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final driver in drivers) {
      if (driver.driverId == id) {
        return driver;
      }
    }
    return null;
  }

  ConstructorStanding? _findFavoriteTeam(List<ConstructorStanding> teams) {
    final id = _favoriteTeamId;
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final team in teams) {
      if (team.constructorId == id) {
        return team;
      }
    }
    return null;
  }

  Future<void> _selectFavoriteDriver(List<DriverStanding> drivers) async {
    final selection = await showModalBottomSheet<DriverStanding>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) {
        return _SelectionSheet<DriverStanding>(
          title: 'Favorite Driver',
          loadItems: () async => drivers,
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
    if (selection == null) {
      return;
    }
    await UserPreferences.setFavoriteDriverId(selection.driverId);
    await WidgetUpdateService.setFavoriteDriverDefault(
      driver: selection,
      season: _season,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _favoriteDriverId = selection.driverId;
    });
  }

  Future<void> _selectFavoriteTeam(
    List<ConstructorStanding> teams,
    List<DriverStanding> drivers,
  ) async {
    final selection = await showModalBottomSheet<_TeamSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) {
        return _SelectionSheet<_TeamSelection>(
          title: 'Favorite Team',
          loadItems: () async {
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
    if (selection == null) {
      return;
    }
    await UserPreferences.setFavoriteTeamId(selection.team.constructorId);
    await WidgetUpdateService.setFavoriteTeamDefault(
      team: selection.team,
      drivers: selection.drivers,
      season: _season,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _favoriteTeamId = selection.team.constructorId;
    });
  }

  String _shortDriverLabel(List<DriverStanding> drivers, int index) {
    if (index >= drivers.length) {
      return 'TBD';
    }
    final driver = drivers[index];
    final code = driver.code?.trim();
    if (code != null && code.isNotEmpty) {
      return code.toUpperCase();
    }
    final family = driver.familyName.trim();
    if (family.isEmpty) {
      return 'TBD';
    }
    return family
        .substring(0, family.length >= 3 ? 3 : family.length)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final content = _buildBody(colors);
    if (!widget.showAppBar) {
      return content;
    }
    return F1Scaffold(
      appBar: AppBar(
        title: Text("GridGlance"),
        actions: [
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: colors.f1RedBright,
            ),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: colors.f1RedBright),
            onPressed: _refresh,
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildBody(AppColors colors) {
    return FutureBuilder<SeasonOverview>(
      future: _overview,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: colors.f1Red));
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              "Unable to reach live data and no cache is available yet.",
              style: TextStyle(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
          );
        }

        final overview = snapshot.data;
        if (overview == null) {
          return Center(
            child: Text(
              "No data available",
              style: TextStyle(color: colors.textMuted),
            ),
          );
        }

        final topDrivers = overview.driverStandings.take(3).toList();
        final topTeams = overview.constructorStandings.take(3).toList();
        final upcomingRaces = _getUpcomingRaces(overview, count: 3);
        final favoriteDriver = _findFavoriteDriver(overview.driverStandings);
        final favoriteTeam = _findFavoriteTeam(overview.constructorStandings);

        if (!_didUpdateWidget) {
          _didUpdateWidget = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            WidgetUpdateService.updateDriverStandings(
              overview.driverStandings,
              season: _season,
            );
            WidgetUpdateService.updateTeamStandings(
              overview.constructorStandings,
              season: _season,
            );
            WidgetUpdateService.updateNextRaceCountdown(
              overview.nextRace,
              season: _season,
            );
            WidgetUpdateService.updateNextSessionWidget(
              overview.raceSchedule,
              season: _season,
            );
          });
        }

        return ListView(
          padding: EdgeInsets.only(bottom: 24),
          physics: BouncingScrollPhysics(),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Text(
                    "Season",
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 12,
                      letterSpacing: 1.6,
                    ),
                  ),
                  SizedBox(width: 10),
                  InkWell(
                    onTap: _selectSeason,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _season,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: colors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (overview.lastUpdated != null)
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    overview.isFromCache
                        ? '${formatLastUpdatedAgo(overview.lastUpdated!)} • Offline cache'
                        : formatLastUpdatedAgo(overview.lastUpdated!),
                    style: TextStyle(color: colors.textMuted, fontSize: 11),
                  ),
                ),
              ),
            Reveal(
              index: 0,
              child: _buildFavoritesCard(
                colors,
                drivers: overview.driverStandings,
                teams: overview.constructorStandings,
                favoriteDriver: favoriteDriver,
                favoriteTeam: favoriteTeam,
              ),
            ),
            Reveal(
              index: 1,
              child: _buildSummaryCard(
                title: "Next Race",
                subtitle: overview.nextRace == null
                    ? null
                    : "Tap for weekend center",
                onTap: overview.nextRace == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RaceWeekendCenterScreen(
                              race: overview.nextRace!,
                              season: _season,
                            ),
                          ),
                        );
                      },
                child: overview.nextRace == null
                    ? _buildEmptyState("No upcoming race data.")
                    : _buildNextRaceSummary(overview.nextRace!),
              ),
            ),
            Reveal(
              index: 2,
              child: _buildSummaryCard(
                title: "Last Race Results",
                subtitle: "Race, qualifying, sprint",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LastRaceResultsScreen(season: _season),
                    ),
                  );
                },
                child: Text(
                  "Tap to view the latest results.",
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ),
            ),
            Reveal(
              index: 3,
              child: _buildSummaryCard(
                title: "Driver Standings",
                subtitle: "Top 3 drivers",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DriverStandingsScreen(
                        standings: overview.driverStandings,
                        season: _season,
                        lastUpdated: overview.driverStandingsUpdatedAt,
                        isFromCache: overview.driverStandingsFromCache,
                      ),
                    ),
                  );
                },
                child: _buildDriverSummary(topDrivers),
              ),
            ),
            Reveal(
              index: 4,
              child: _buildSummaryCard(
                title: "Team Standings",
                subtitle: "Top 3 teams",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ConstructorStandingsScreen(
                        standings: overview.constructorStandings,
                        season: _season,
                        lastUpdated: overview.constructorStandingsUpdatedAt,
                        isFromCache: overview.constructorStandingsFromCache,
                      ),
                    ),
                  );
                },
                child: _buildTeamSummary(topTeams),
              ),
            ),
            Reveal(
              index: 5,
              child: _buildSummaryCard(
                title: "Upcoming Races",
                subtitle: "Next 3 races",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RaceScheduleScreen(
                        races: overview.raceSchedule,
                        season: _season,
                        lastUpdated: overview.raceScheduleUpdatedAt,
                        isFromCache: overview.raceScheduleFromCache,
                      ),
                    ),
                  );
                },
                child: _buildRaceSummary(upcomingRaces),
              ),
            ),
            Reveal(
              index: 6,
              child: _buildSummaryCard(
                title: "Compare Mode",
                subtitle: "Driver / team head-to-head",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CompareModeScreen(season: _season),
                    ),
                  );
                },
                child: Text(
                  "Pick two drivers or teams and compare points trend, finishes, quali delta, podiums, and wins.",
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Race> _getUpcomingRaces(SeasonOverview overview, {int count = 3}) {
    if (overview.raceSchedule.isEmpty) {
      return [];
    }

    int startIndex = 0;
    final nextRound = overview.nextRace?.round;
    if (nextRound != null) {
      final nextIndex = overview.raceSchedule.indexWhere(
        (race) => race.round == nextRound,
      );
      if (nextIndex >= 0) {
        startIndex = nextIndex;
      }
    }

    final endIndex = min(startIndex + count, overview.raceSchedule.length);
    return overview.raceSchedule.sublist(startIndex, endIndex);
  }

  Widget _buildSummaryCard({
    required String title,
    required Widget child,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: colors.textMuted),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ),
          SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildFavoritesCard(
    AppColors colors, {
    required List<DriverStanding> drivers,
    required List<ConstructorStanding> teams,
    required DriverStanding? favoriteDriver,
    required ConstructorStanding? favoriteTeam,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final driverTitle = favoriteDriver == null
        ? 'Select favorite driver'
        : '${favoriteDriver.givenName} ${favoriteDriver.familyName}';
    final driverSubtitle = favoriteDriver == null
        ? 'Tap to choose'
        : '${favoriteDriver.teamName} • ${favoriteDriver.points} pts';
    final teamTitle = favoriteTeam == null
        ? 'Select favorite team'
        : favoriteTeam.teamName;
    final teamSubtitle = favoriteTeam == null
        ? 'Tap to choose'
        : 'P${favoriteTeam.position} • ${favoriteTeam.points} pts';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: colors.f1RedBright, size: 18),
              SizedBox(width: 8),
              Text(
                'Favorites',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildFavoriteRow(
            label: 'Driver',
            title: driverTitle,
            subtitle: driverSubtitle,
            leading: favoriteDriver == null
                ? Icon(Icons.person_outline, color: colors.textMuted)
                : TeamLogo(teamName: favoriteDriver.teamName, size: 22),
            onTap: drivers.isEmpty
                ? null
                : () => _selectFavoriteDriver(drivers),
          ),
          SizedBox(height: 10),
          _buildFavoriteRow(
            label: 'Team',
            title: teamTitle,
            subtitle: teamSubtitle,
            leading: favoriteTeam == null
                ? Icon(Icons.shield_outlined, color: colors.textMuted)
                : TeamLogo(teamName: favoriteTeam.teamName, size: 22),
            onTap: teams.isEmpty
                ? null
                : () => _selectFavoriteTeam(teams, drivers),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteRow({
    required String label,
    required String title,
    required String subtitle,
    required Widget leading,
    required VoidCallback? onTap,
  }) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  leading,
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.edit, size: 16, color: colors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverSummary(List<DriverStanding> drivers) {
    if (drivers.isEmpty) {
      return _buildEmptyState("No driver standings available.");
    }

    return Column(
      children: drivers
          .map(
            (driver) => _buildSummaryRow(
              leading: "#${driver.position}",
              prefix: TeamLogo(teamName: driver.teamName, size: 22),
              title: "${driver.givenName} ${driver.familyName}",
              subtitle: driver.teamName,
              trailing: "${driver.points} PTS",
            ),
          )
          .toList(),
    );
  }

  Widget _buildTeamSummary(List<ConstructorStanding> teams) {
    if (teams.isEmpty) {
      return _buildEmptyState("No team standings available.");
    }

    return Column(
      children: teams
          .map(
            (team) => _buildSummaryRow(
              leading: "#${team.position}",
              prefix: TeamLogo(teamName: team.teamName, size: 22),
              title: team.teamName,
              subtitle: "Constructors",
              trailing: "${team.points} PTS",
            ),
          )
          .toList(),
    );
  }

  Widget _buildRaceSummary(List<Race> races) {
    if (races.isEmpty) {
      return _buildEmptyState("No race schedule available.");
    }

    return Column(
      children: races
          .map(
            (race) => _buildSummaryRow(
              leading: "R${race.round}",
              title: race.raceName,
              subtitle: race.location,
              trailing: _localRaceDateLabel(race),
            ),
          )
          .toList(),
    );
  }

  String _localRaceDateLabel(Race race) {
    final start = race.startDateTime;
    if (start == null) {
      return race.date;
    }
    if (race.time == null || race.time!.isEmpty) {
      return formatLocalDate(context, start);
    }
    return formatLocalDateTime(context, start);
  }

  Widget _buildNextRaceSummary(Race race) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final start = race.startDateTime;
    final dateLabel = start == null
        ? race.date
        : (race.time == null || race.time!.isEmpty)
        ? formatLocalDate(context, start)
        : formatLocalDateTime(context, start);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatPill(
              text: "Round ${race.round}",
              color: AppColors.of(context).f1Red,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                dateLabel,
                style: TextStyle(
                  color: AppColors.of(context).textMuted,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (start != null)
          Padding(
            padding: EdgeInsets.only(top: 6),
            child: CountdownText(
              target: start,
              style: TextStyle(
                color: AppColors.of(context).textMuted,
                fontSize: 11,
              ),
            ),
          ),
        SizedBox(height: 10),
        Text(
          race.raceName,
          style: TextStyle(
            color: onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: 4),
        Text(
          "${race.circuitName} - ${race.location}",
          style: TextStyle(
            color: AppColors.of(context).textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow({
    required String leading,
    Widget? prefix,
    required String title,
    String? subtitle,
    String? trailing,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              leading,
              style: TextStyle(
                color: AppColors.of(context).f1RedBright,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ),
          if (prefix != null) ...[prefix, SizedBox(width: 8)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.of(context).textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: TextStyle(
                color: AppColors.of(context).textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Text(
      message,
      style: TextStyle(color: AppColors.of(context).textMuted, fontSize: 12),
    );
  }
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
