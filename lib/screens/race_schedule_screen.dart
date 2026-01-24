import 'package:flutter/material.dart';
import '../models/race.dart';
import '../theme/app_theme.dart';
import '../widgets/f1_scaffold.dart';
import '../widgets/reveal.dart';
import '../widgets/season_cards.dart';

class RaceScheduleScreen extends StatelessWidget {
  final List<Race> races;
  final String season;

  const RaceScheduleScreen({
    super.key,
    required this.races,
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
            Text("Race Schedule"),
            Text(
              "Season $season",
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      body: races.isEmpty
          ? Center(
              child: Text(
                "No race schedule available.",
                style: TextStyle(color: colors.textMuted),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.only(bottom: 24),
              physics: BouncingScrollPhysics(),
              itemCount: races.length,
              itemBuilder: (context, index) {
                return Reveal(index: index, child: RaceCard(race: races[index]));
              },
            ),
    );
  }
}
