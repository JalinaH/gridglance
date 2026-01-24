import 'dart:math';
import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../models/constructor_standing.dart';
import '../models/driver_standing.dart';
import '../models/race.dart';
import '../models/season_overview.dart';
import '../theme/app_theme.dart';
import '../widgets/f1_scaffold.dart';
import '../widgets/reveal.dart';
import '../widgets/season_cards.dart';
import 'constructor_standings_screen.dart';
import 'driver_standings_screen.dart';
import 'race_detail_screen.dart';
import 'race_schedule_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _season = '2025';
  late Future<SeasonOverview> _overview;

  @override
  void initState() {
    super.initState();
    _overview = ApiService().getSeasonOverview(season: _season);
  }

  void _refresh() {
    setState(() {
      _overview = ApiService().getSeasonOverview(season: _season);
    });
  }

  @override
  Widget build(BuildContext context) {
    return F1Scaffold(
      appBar: AppBar(
        title: Text("GridGlance"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.f1RedBright),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<SeasonOverview>(
        future: _overview,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppTheme.f1Red),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading data",
                style: TextStyle(color: AppTheme.textMuted),
              ),
            );
          }

          final overview = snapshot.data;
          if (overview == null) {
            return Center(
              child: Text(
                "No data available",
                style: TextStyle(color: AppTheme.textMuted),
              ),
            );
          }

          final topDrivers = overview.driverStandings.take(3).toList();
          final topTeams = overview.constructorStandings.take(3).toList();
          final upcomingRaces = _getUpcomingRaces(overview, count: 3);

          return ListView(
            padding: EdgeInsets.only(bottom: 24),
            physics: BouncingScrollPhysics(),
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  "Season $_season",
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              Reveal(
                index: 0,
                child: _buildSummaryCard(
                  title: "Next Race",
                  subtitle:
                      overview.nextRace == null ? null : "Tap for full details",
                  onTap: overview.nextRace == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RaceDetailScreen(
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
                index: 1,
                child: _buildSummaryCard(
                  title: "Driver Standings",
                  subtitle: "Top 3 drivers",
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DriverStandingsScreen(
                          standings: overview.driverStandings,
                          season: _season,
                        ),
                      ),
                    );
                  },
                  child: _buildDriverSummary(topDrivers),
                ),
              ),
              Reveal(
                index: 2,
                child: _buildSummaryCard(
                  title: "Team Standings",
                  subtitle: "Top 3 teams",
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ConstructorStandingsScreen(
                          standings: overview.constructorStandings,
                          season: _season,
                        ),
                      ),
                    );
                  },
                  child: _buildTeamSummary(topTeams),
                ),
              ),
              Reveal(
                index: 3,
                child: _buildSummaryCard(
                  title: "Upcoming Races",
                  subtitle: "Next 3 races",
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RaceScheduleScreen(
                          races: overview.raceSchedule,
                          season: _season,
                        ),
                      ),
                    );
                  },
                  child: _buildRaceSummary(upcomingRaces),
                ),
              ),
            ],
          );
        },
      ),
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
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: AppTheme.textMuted),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ),
          SizedBox(height: 10),
          child,
        ],
      ),
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
              trailing: race.date,
            ),
          )
          .toList(),
    );
  }

  Widget _buildNextRaceSummary(Race race) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatPill(
              text: "Round ${race.round}",
              color: AppTheme.f1Red,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                race.displayDateTime,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Text(
          race.raceName,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: 4),
        Text(
          "${race.circuitName} - ${race.location}",
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSummaryRow({
    required String leading,
    required String title,
    String? subtitle,
    String? trailing,
  }) {
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
                color: AppTheme.f1RedBright,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.textMuted,
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
                color: Colors.white70,
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
      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
    );
  }
}
