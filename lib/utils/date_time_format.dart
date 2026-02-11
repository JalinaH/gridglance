import 'package:flutter/material.dart';

String formatLocalDate(BuildContext context, DateTime dateTime) {
  final local = dateTime.toLocal();
  return MaterialLocalizations.of(context).formatShortDate(local);
}

String formatLocalDateTime(BuildContext context, DateTime dateTime) {
  final local = dateTime.toLocal();
  final localizations = MaterialLocalizations.of(context);
  final dateLabel = localizations.formatShortDate(local);
  final timeLabel = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: false,
  );
  return '$dateLabel - $timeLabel';
}

String formatLastUpdatedAgo(DateTime updatedAt, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  final localUpdatedAt = updatedAt.toLocal();
  var difference = current.difference(localUpdatedAt);
  if (difference.isNegative) {
    difference = Duration.zero;
  }
  if (difference.inMinutes < 1) {
    return 'Last updated just now';
  }
  if (difference.inMinutes < 60) {
    final mins = difference.inMinutes;
    final suffix = mins == 1 ? 'min' : 'mins';
    return 'Last updated $mins $suffix ago';
  }
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    final suffix = hours == 1 ? 'hour' : 'hours';
    return 'Last updated $hours $suffix ago';
  }
  final days = difference.inDays;
  final suffix = days == 1 ? 'day' : 'days';
  return 'Last updated $days $suffix ago';
}
