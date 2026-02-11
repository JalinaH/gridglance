import 'package:flutter/widgets.dart';

import '../models/race.dart';
import 'race_detail_screen.dart';

class RaceWeekendCenterScreen extends StatelessWidget {
  final Race race;
  final String season;

  const RaceWeekendCenterScreen({
    super.key,
    required this.race,
    required this.season,
  });

  @override
  Widget build(BuildContext context) {
    return RaceDetailScreen(race: race, season: season);
  }
}
