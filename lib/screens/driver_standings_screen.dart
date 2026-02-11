import 'package:flutter/material.dart';
import '../models/driver_standing.dart';
import '../screens/driver_detail_screen.dart';
import '../theme/app_theme.dart';
import '../utils/date_time_format.dart';
import '../widgets/compact_search_field.dart';
import '../widgets/f1_scaffold.dart';
import '../widgets/reveal.dart';
import '../widgets/season_cards.dart';

class DriverStandingsScreen extends StatefulWidget {
  final List<DriverStanding> standings;
  final String season;
  final DateTime? lastUpdated;
  final bool isFromCache;

  const DriverStandingsScreen({
    super.key,
    required this.standings,
    required this.season,
    this.lastUpdated,
    this.isFromCache = false,
  });

  @override
  State<DriverStandingsScreen> createState() => _DriverStandingsScreenState();
}

class _DriverStandingsScreenState extends State<DriverStandingsScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<DriverStanding> get _filteredStandings {
    if (_query.isEmpty) {
      return widget.standings;
    }
    final query = _query.toLowerCase();
    return widget.standings.where((driver) {
      final name = '${driver.givenName} ${driver.familyName}'.toLowerCase();
      final team = driver.teamName.toLowerCase();
      return name.contains(query) ||
          team.contains(query) ||
          driver.position.toLowerCase().contains(query) ||
          driver.points.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final standings = _filteredStandings;
    return F1Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Driver Standings"),
            Text(
              "Season ${widget.season}",
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      body: widget.standings.isEmpty
          ? Center(
              child: Text(
                "No driver standings available.",
                style: TextStyle(color: colors.textMuted),
              ),
            )
          : Column(
              children: [
                if (widget.lastUpdated != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.isFromCache
                            ? '${formatLastUpdatedAgo(widget.lastUpdated!)} • Offline cache'
                            : formatLastUpdatedAgo(widget.lastUpdated!),
                        style: TextStyle(color: colors.textMuted, fontSize: 11),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: CompactSearchField(
                    controller: _controller,
                    hintText: 'Search drivers or teams',
                    onChanged: (value) {
                      setState(() {
                        _query = value.trim();
                      });
                    },
                    onClear: _query.isEmpty
                        ? null
                        : () {
                            _controller.clear();
                            setState(() {
                              _query = '';
                            });
                          },
                  ),
                ),
                Expanded(
                  child: standings.isEmpty
                      ? Center(
                          child: Text(
                            "No matching drivers.",
                            style: TextStyle(color: colors.textMuted),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.only(bottom: 24),
                          physics: BouncingScrollPhysics(),
                          itemCount: standings.length,
                          itemBuilder: (context, index) {
                            return Reveal(
                              index: index,
                              child: DriverStandingCard(
                                driver: standings[index],
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => DriverDetailScreen(
                                        driver: standings[index],
                                        season: widget.season,
                                      ),
                                    ),
                                  );
                                },
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
