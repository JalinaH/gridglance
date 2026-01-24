import 'package:flutter/material.dart';
import '../models/driver_standing.dart';
import '../theme/app_theme.dart';
import '../widgets/f1_scaffold.dart';
import '../widgets/reveal.dart';
import '../widgets/season_cards.dart';

class DriverStandingsScreen extends StatelessWidget {
  final List<DriverStanding> standings;
  final String season;

  const DriverStandingsScreen({
    super.key,
    required this.standings,
    required this.season,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return F1Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Driver Standings"),
            Text(
              "Season $season",
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      body: standings.isEmpty
          ? Center(
              child: Text(
                "No driver standings available.",
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
                  child: DriverStandingCard(driver: standings[index]),
                );
              },
            ),
    );
  }
}
