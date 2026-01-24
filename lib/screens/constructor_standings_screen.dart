import 'package:flutter/material.dart';
import '../models/constructor_standing.dart';
import '../theme/app_theme.dart';
import '../widgets/f1_scaffold.dart';
import '../widgets/reveal.dart';
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
    return F1Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Team Standings"),
            Text(
              "Season $season",
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      body: standings.isEmpty
          ? Center(
              child: Text(
                "No team standings available.",
                style: TextStyle(color: AppTheme.textMuted),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.only(bottom: 24),
              physics: BouncingScrollPhysics(),
              itemCount: standings.length,
              itemBuilder: (context, index) {
                return Reveal(
                  index: index,
                  child: ConstructorStandingCard(team: standings[index]),
                );
              },
            ),
    );
  }
}
