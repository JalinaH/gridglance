/// Where a tap on a home screen widget should take the user.
enum WidgetDestination {
  /// Pick a driver/team for a favorite widget.
  favoriteDriverConfig,
  favoriteTeamConfig,
  driverDetail,
  teamDetail,
  driverStandings,
  teamStandings,
  raceDetail,
}

/// Parsed payload of a widget click forwarded by the native side over the
/// `gridglance/widget_intent` channel.
class WidgetClickTarget {
  final WidgetDestination destination;
  final int widgetId;

  /// `driverId` / `constructorId` for detail destinations, otherwise null.
  final String? targetId;

  const WidgetClickTarget({
    required this.destination,
    required this.widgetId,
    this.targetId,
  });

  /// Returns null when the payload is malformed or the type is unknown.
  static WidgetClickTarget? fromPayload(Map<dynamic, dynamic>? payload) {
    if (payload == null) {
      return null;
    }
    final type = payload['type'] as String?;
    final widgetId = int.tryParse('${payload['widgetId'] ?? ''}');
    if (type == null || widgetId == null) {
      return null;
    }
    final rawTarget = (payload['targetId'] as String?)?.trim();
    final targetId = (rawTarget == null || rawTarget.isEmpty)
        ? null
        : rawTarget;

    WidgetClickTarget to(WidgetDestination destination, {String? id}) =>
        WidgetClickTarget(
          destination: destination,
          widgetId: widgetId,
          targetId: id,
        );

    switch (type) {
      case 'favorite_driver_config':
        return to(WidgetDestination.favoriteDriverConfig);
      case 'favorite_team_config':
        return to(WidgetDestination.favoriteTeamConfig);
      case 'favorite_driver':
        // Unconfigured widgets (no driver yet) open the picker.
        return targetId == null
            ? to(WidgetDestination.favoriteDriverConfig)
            : to(WidgetDestination.driverDetail, id: targetId);
      case 'favorite_team':
        return targetId == null
            ? to(WidgetDestination.favoriteTeamConfig)
            : to(WidgetDestination.teamDetail, id: targetId);
      case 'driver_standings':
        return targetId == null
            ? to(WidgetDestination.driverStandings)
            : to(WidgetDestination.driverDetail, id: targetId);
      case 'team_standings':
        return targetId == null
            ? to(WidgetDestination.teamStandings)
            : to(WidgetDestination.teamDetail, id: targetId);
      case 'race_weekend':
        return to(WidgetDestination.raceDetail);
      default:
        return null;
    }
  }
}
