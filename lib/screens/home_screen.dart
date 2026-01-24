import 'dart:math';
import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../models/constructor_standing.dart';
import '../models/driver_standing.dart';
import '../models/race.dart';
import '../models/season_overview.dart';
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          "GridGlance",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<SeasonOverview>(
        future: _overview,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Colors.red));
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading data",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final overview = snapshot.data;
          if (overview == null) {
            return Center(
              child: Text(
                "No data available",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final topDrivers = overview.driverStandings.take(3).toList();
          final topTeams = overview.constructorStandings.take(3).toList();
          final upcomingRaces = _getUpcomingRaces(overview, count: 3);

          return ListView(
            padding: EdgeInsets.only(top: 12, bottom: 24),
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  "Season $_season",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              _buildSummaryCard(
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
              _buildSummaryCard(
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
              _buildSummaryCard(
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
              _buildSummaryCard(
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                style: TextStyle(color: Colors.grey, fontSize: 12),
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
              color: Colors.redAccent.withOpacity(0.8),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                race.displayDateTime,
                style: TextStyle(color: Colors.grey, fontSize: 12),
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
          ),
        ),
        SizedBox(height: 4),
        Text(
          "${race.circuitName} - ${race.location}",
          style: TextStyle(color: Colors.grey, fontSize: 13),
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
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
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
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey, fontSize: 11),
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
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Text(
      message,
      style: TextStyle(color: Colors.grey, fontSize: 12),
    );
  }
}
