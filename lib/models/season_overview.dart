import 'constructor_standing.dart';
import 'driver_standing.dart';
import 'race.dart';

class SeasonOverview {
  final List<DriverStanding> driverStandings;
  final List<ConstructorStanding> constructorStandings;
  final Race? nextRace;
  final List<Race> raceSchedule;

  SeasonOverview({
    required this.driverStandings,
    required this.constructorStandings,
    required this.nextRace,
    required this.raceSchedule,
  });
}
