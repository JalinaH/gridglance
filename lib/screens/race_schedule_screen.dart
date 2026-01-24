import 'package:flutter/material.dart';
import '../models/race.dart';
import '../widgets/season_cards.dart';

class RaceScheduleScreen extends StatelessWidget {
  final List<Race> races;
  final String season;

  const RaceScheduleScreen({
    required this.races,
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
            Text("Race Schedule"),
            Text(
              "Season $season",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: races.isEmpty
          ? Center(
              child: Text(
                "No race schedule available.",
                style: TextStyle(color: Colors.white70),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.only(top: 12, bottom: 20),
              itemCount: races.length,
              itemBuilder: (context, index) {
                return RaceCard(race: races[index]);
              },
            ),
    );
  }
}
