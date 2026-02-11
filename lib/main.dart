import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/main_shell.dart';
import 'screens/widget_config_screen.dart';
import 'services/background_task_service.dart';
import 'services/favorite_result_alert_service.dart';
import 'services/notification_service.dart';
import 'services/widget_update_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetUpdateService.ensureHomeWidgetSetup();
  await NotificationService.init();
  await BackgroundTaskService.initializeAndSchedule();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const String _themeKey = 'theme_mode';
  static const MethodChannel _widgetIntentChannel = MethodChannel(
    'gridglance/widget_intent',
  );
  ThemeMode _themeMode = ThemeMode.dark;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThemeMode();
    _checkForWidgetClick();
    _runBackgroundChecks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForWidgetClick();
      _runBackgroundChecks();
    }
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themeKey);
    final mode = stored == 'light' ? ThemeMode.light : ThemeMode.dark;
    if (!mounted) {
      return;
    }
    setState(() {
      _themeMode = mode;
    });
  }

  Future<void> _toggleTheme() async {
    final nextMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    if (mounted) {
      setState(() {
        _themeMode = nextMode;
      });
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeKey,
      nextMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  bool get _isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> _checkForWidgetClick() async {
    final result = await _widgetIntentChannel
        .invokeMethod<Map<dynamic, dynamic>?>('consumeWidgetClick');
    if (result == null) {
      return;
    }
    final type = result['type'] as String?;
    final widgetId = int.tryParse('${result['widgetId'] ?? ''}');
    if (type == null || widgetId == null) {
      return;
    }
    final route = MaterialPageRoute(
      builder: (_) => WidgetConfigScreen(
        type: type == 'favorite_team'
            ? WidgetConfigType.team
            : WidgetConfigType.driver,
        widgetId: widgetId,
        season: DateTime.now().year.toString(),
      ),
    );
    _navigatorKey.currentState?.push(route);
  }

  void _runBackgroundChecks() {
    unawaited(FavoriteResultAlertService.checkForUpdates());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GridGlance',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      navigatorKey: _navigatorKey,
      home: MainShell(isDarkMode: _isDarkMode, onToggleTheme: _toggleTheme),
    );
  }
}
