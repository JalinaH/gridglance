import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../models/constructor_standing.dart';
import '../models/driver_standing.dart';
import '../services/widget_update_service.dart';
import '../theme/app_theme.dart';

enum WidgetConfigType { driver, team }

class WidgetConfigScreen extends StatelessWidget {
  final WidgetConfigType type;
  final int widgetId;
  final String season;

  const WidgetConfigScreen({
    super.key,
    required this.type,
    required this.widgetId,
    required this.season,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(type == WidgetConfigType.driver ? 'Select Driver' : 'Select Team'),
      ),
      body: type == WidgetConfigType.driver
          ? _DriverSelector(
              widgetId: widgetId,
              season: season,
            )
          : _TeamSelector(
              widgetId: widgetId,
              season: season,
            ),
    );
  }
}

class _DriverSelector extends StatelessWidget {
  final int widgetId;
  final String season;

  const _DriverSelector({
    required this.widgetId,
    required this.season,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return FutureBuilder<List<DriverStanding>>(
      future: ApiService().getDriverStandings(season: season),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: colors.f1Red),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Text(
              'Failed to load drivers',
              style: TextStyle(color: colors.textMuted),
            ),
          );
        }
        final drivers = snapshot.data!;
        return ListView.separated(
          itemCount: drivers.length,
          separatorBuilder: (_, __) => Divider(color: colors.border),
          itemBuilder: (context, index) {
            final driver = drivers[index];
            return ListTile(
              title: Text(
                '${driver.givenName} ${driver.familyName}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              subtitle: Text(
                '${driver.teamName} • ${driver.points} pts',
                style: TextStyle(color: colors.textMuted),
              ),
              trailing: Text(
                'P${driver.position}',
                style: TextStyle(color: colors.textMuted),
              ),
              onTap: () async {
                await WidgetUpdateService.configureFavoriteDriverWidget(
                  widgetId: widgetId,
                  driver: driver,
                  season: season,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          },
        );
      },
    );
  }
}

class _TeamSelector extends StatelessWidget {
  final int widgetId;
  final String season;

  const _TeamSelector({
    required this.widgetId,
    required this.season,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return FutureBuilder<_TeamSelectorData>(
      future: _loadData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: colors.f1Red),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Text(
              'Failed to load teams',
              style: TextStyle(color: colors.textMuted),
            ),
          );
        }
        final data = snapshot.data!;
        return ListView.separated(
          itemCount: data.teams.length,
          separatorBuilder: (_, __) => Divider(color: colors.border),
          itemBuilder: (context, index) {
            final team = data.teams[index];
            final drivers = data.drivers
                .where((driver) => driver.constructorId == team.constructorId)
                .take(2)
                .toList();
            final driverLabel = drivers.isEmpty
                ? 'Drivers TBD'
                : drivers
                    .map((driver) => _driverLabel(driver))
                    .join('  ');
            return ListTile(
              title: Text(
                team.teamName,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              subtitle: Text(
                '$driverLabel • ${team.points} pts',
                style: TextStyle(color: colors.textMuted),
              ),
              trailing: Text(
                'P${team.position}',
                style: TextStyle(color: colors.textMuted),
              ),
              onTap: () async {
                await WidgetUpdateService.configureFavoriteTeamWidget(
                  widgetId: widgetId,
                  team: team,
                  drivers: drivers,
                  season: season,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          },
        );
      },
    );
  }

  Future<_TeamSelectorData> _loadData() async {
    final api = ApiService();
    final results = await Future.wait([
      api.getConstructorStandings(season: season),
      api.getDriverStandings(season: season),
    ]);
    return _TeamSelectorData(
      teams: results[0] as List<ConstructorStanding>,
      drivers: results[1] as List<DriverStanding>,
    );
  }

  String _driverLabel(DriverStanding driver) {
    final number = driver.permanentNumber ?? '--';
    final code = driver.code?.isNotEmpty == true
        ? driver.code!
        : (driver.familyName.isNotEmpty
            ? driver.familyName.substring(
                0,
                driver.familyName.length >= 3 ? 3 : driver.familyName.length,
              )
            : '---');
    return '${number.toUpperCase()} ${code.toUpperCase()}';
  }
}

class _TeamSelectorData {
  final List<ConstructorStanding> teams;
  final List<DriverStanding> drivers;

  const _TeamSelectorData({
    required this.teams,
    required this.drivers,
  });
}
