import 'package:flutter/material.dart';
import '../models/constructor_standing.dart';
import '../widgets/season_cards.dart';

class ConstructorStandingsScreen extends StatelessWidget {
  final List<ConstructorStanding> standings;
  final String season;

  const ConstructorStandingsScreen({
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
            Text("Team Standings"),
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
                "No team standings available.",
                style: TextStyle(color: Colors.white70),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.only(top: 12, bottom: 20),
              itemCount: standings.length,
              itemBuilder: (context, index) {
                return ConstructorStandingCard(team: standings[index]);
              },
            ),
    );
  }
}
