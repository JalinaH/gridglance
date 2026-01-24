import 'package:flutter/material.dart';
import '../models/driver_standing.dart';
import '../widgets/season_cards.dart';

class DriverStandingsScreen extends StatelessWidget {
  final List<DriverStanding> standings;
  final String season;

  const DriverStandingsScreen({
    required this.standings,
    required this.season,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Driver Standings"),
            Text(
              "Season $season",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: standings.isEmpty
          ? Center(
              child: Text(
                "No driver standings available.",
                style: TextStyle(color: Colors.white70),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.only(top: 12, bottom: 20),
              itemCount: standings.length,
              itemBuilder: (context, index) {
                return DriverStandingCard(driver: standings[index]);
              },
            ),
    );
  }
}
