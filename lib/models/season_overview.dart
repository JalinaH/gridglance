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

  /// Season the standings belong to. Differs from the requested season only
  /// in the off-season, when the new season has no standings yet and last
  /// season's final standings are shown in their place.
  final String? standingsSeason;

  /// True when [driverStandings] and [constructorStandings] are the previous
  /// season's final standings.
  final bool isOffSeason;

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
    this.standingsSeason,
    this.isOffSeason = false,
  });
}
