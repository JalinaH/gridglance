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
