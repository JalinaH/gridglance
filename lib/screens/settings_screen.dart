import 'dart:async';

import 'package:flutter/material.dart';

import '../services/analytics.dart';
import '../services/favorite_result_alert_service.dart';
import '../services/notification_preferences.dart';
import '../services/user_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../widgets/f1_scaffold.dart';

/// One place for the app's preferences: theme, favorite alerts, the default
/// reminder time and anonymous usage data.
class SettingsScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeMode _themeMode = widget.themeMode;
  bool _loading = true;
  bool _busy = false;
  bool _sessionFinishedAlerts = false;
  bool _positionPointsAlerts = false;
  int _defaultLeadMinutes = NotificationPreferences.defaultLeadTimeMinutes;
  bool _analyticsEnabled = !Analytics.isOptedOut;
  bool _hasFavorite = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessionFinished =
        await NotificationPreferences.isFavoriteSessionFinishedEnabled();
    final positionPoints =
        await NotificationPreferences.isFavoritePositionPointsEnabled();
    final leadMinutes =
        await NotificationPreferences.getDefaultLeadTimeMinutes();
    final driver = await UserPreferences.getFavoriteDriverId();
    final team = await UserPreferences.getFavoriteTeamId();
    if (!mounted) return;
    setState(() {
      _sessionFinishedAlerts = sessionFinished;
      _positionPointsAlerts = positionPoints;
      _defaultLeadMinutes = leadMinutes;
      _hasFavorite =
          (driver != null && driver.isNotEmpty) ||
          (team != null && team.isNotEmpty);
      _loading = false;
    });
  }

  void _setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    Haptics.selection();
    setState(() => _themeMode = mode);
    widget.onThemeModeChanged(mode);
  }

  Future<void> _setAlert(FavoriteAlertKind kind, bool enabled) async {
    if (_busy) return;
    Haptics.selection();
    setState(() => _busy = true);
    var changed = false;
    try {
      changed = await FavoriteResultAlertService.setAlertEnabled(kind, enabled);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (!changed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notifications are off for GridGlance. '
            'Turn them on in system settings.',
          ),
        ),
      );
      return;
    }
    setState(() {
      switch (kind) {
        case FavoriteAlertKind.sessionFinished:
          _sessionFinishedAlerts = enabled;
        case FavoriteAlertKind.positionPoints:
          _positionPointsAlerts = enabled;
      }
    });
  }

  Future<void> _setDefaultLead(int minutes) async {
    if (minutes == _defaultLeadMinutes) return;
    Haptics.selection();
    setState(() => _defaultLeadMinutes = minutes);
    await NotificationPreferences.setDefaultLeadTimeMinutes(minutes);
  }

  Future<void> _setAnalytics(bool enabled) async {
    setState(() => _analyticsEnabled = enabled);
    await Analytics.setOptOut(!enabled);
  }

  static String leadTimeLabel(int minutes) =>
      SettingsScreenLabels.leadTime(minutes);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return F1Scaffold(
      maxContentWidth: 700,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _sectionHeader('APPEARANCE'),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title('Theme'),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {_themeMode},
                    onSelectionChanged: (selection) =>
                        _setThemeMode(selection.first),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader('NOTIFICATIONS'),
          if (!_loading && !_hasFavorite)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                'Pick a favorite driver or team on the Home tab to get '
                'favorite alerts.',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ),
          _switchCard(
            icon: Icons.flag_outlined,
            title: 'Favorite session results',
            subtitle:
                'When a race, sprint or qualifying session your favorite '
                'took part in finishes.',
            value: _sessionFinishedAlerts,
            onChanged: _loading || _busy
                ? null
                : (value) =>
                      _setAlert(FavoriteAlertKind.sessionFinished, value),
          ),
          _switchCard(
            icon: Icons.leaderboard_outlined,
            title: 'Favorite standings changes',
            subtitle: 'When your favorite moves position or gains points.',
            value: _positionPointsAlerts,
            onChanged: _loading || _busy
                ? null
                : (value) => _setAlert(FavoriteAlertKind.positionPoints, value),
          ),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title('Default reminder time'),
                const SizedBox(height: 2),
                Text(
                  'How long before a session new reminders go off. You can '
                  'still change each reminder on its race screen.',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final minutes
                        in NotificationPreferences.leadTimePresets)
                      ChoiceChip(
                        label: Text(leadTimeLabel(minutes)),
                        selected: minutes == _defaultLeadMinutes,
                        onSelected: _loading
                            ? null
                            : (_) => unawaited(_setDefaultLead(minutes)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader('PRIVACY'),
          _switchCard(
            icon: Icons.analytics_outlined,
            title: 'Send anonymous usage data',
            subtitle:
                'Helps improve the app. No personal info, no driver/team picks.',
            value: _analyticsEnabled,
            onChanged: _setAnalytics,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          color: colors.f1Red,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _title(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _card({required Widget child}) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }

  Widget _switchCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.f1Red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(title),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: colors.f1Red,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Display text shared by the Settings screen and its tests.
class SettingsScreenLabels {
  SettingsScreenLabels._();

  static String leadTime(int minutes) {
    if (minutes >= 1440 && minutes % 1440 == 0) {
      final days = minutes ~/ 1440;
      return days == 1 ? '1 day' : '$days days';
    }
    if (minutes >= 60 && minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return hours == 1 ? '1 hour' : '$hours hours';
    }
    return '$minutes min';
  }
}
