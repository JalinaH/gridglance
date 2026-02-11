import 'constructor_standing.dart';
import 'driver_standing.dart';
import 'race.dart';

class SeasonOverview {
  final List<DriverStanding> driverStandings;
  final List<ConstructorStanding> constructorStandings;
  final Race? nextRace;
  final List<Race> raceSchedule;
  final DateTime? driverStandingsUpdatedAt;
  final DateTime? constructorStandingsUpdatedAt;
  final DateTime? raceScheduleUpdatedAt;
  final bool driverStandingsFromCache;
  final bool constructorStandingsFromCache;
  final bool raceScheduleFromCache;
  final DateTime? lastUpdated;
  final bool isFromCache;

  SeasonOverview({
    required this.driverStandings,
    required this.constructorStandings,
    required this.nextRace,
    required this.raceSchedule,
    this.driverStandingsUpdatedAt,
    this.constructorStandingsUpdatedAt,
    this.raceScheduleUpdatedAt,
    this.driverStandingsFromCache = false,
    this.constructorStandingsFromCache = false,
    this.raceScheduleFromCache = false,
    this.lastUpdated,
    this.isFromCache = false,
  });
}
