import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'data/api_service.dart';
import 'firebase_options.dart';
import 'screens/constructor_standings_screen.dart';
import 'screens/driver_detail_screen.dart';
import 'screens/driver_standings_screen.dart';
import 'screens/main_shell.dart';
import 'screens/race_detail_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/team_detail_screen.dart';
import 'screens/widget_config_screen.dart';
import 'services/analytics.dart';
import 'services/app_update_messaging_service.dart';
import 'services/app_update_service.dart';
import 'services/background_task_service.dart';
import 'services/crash_reporting.dart';
import 'services/favorite_result_alert_service.dart';
import 'services/notification_service.dart';
import 'services/f1_image_service.dart';
import 'services/user_preferences.dart';
import 'services/widget_click_router.dart';
import 'services/widget_update_service.dart';
import 'theme/app_theme.dart';

/// Upper bound on how long the first launch waits for driver headshot data
/// before showing UI. The fetch keeps running afterwards and fills the cache.
const Duration _imagePrefetchBudget = Duration(seconds: 3);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CrashReporting.runWithCrashReporting(() async {
    // Local-only setup the first frame depends on. Each step is isolated so a
    // single failure degrades that feature instead of leaving a blank screen.
    final firebaseReady = await _initStep(
      'firebase',
      () => Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
    );
    await _initStep('user_preferences', UserPreferences.init);
    await _initStep('analytics', Analytics.init);
    await _initStep('home_widget', WidgetUpdateService.ensureHomeWidgetSetup);
    await _initStep(
      'f1_images',
      () => F1ImageService.instance.init().timeout(
        _imagePrefetchBudget,
        onTimeout: () {},
      ),
    );

    runApp(const MyApp());

    // Everything below may hit the network or show a permission prompt, so it
    // runs after the first frame is scheduled and never blocks launch.
    unawaited(_initStep('notifications', NotificationService.init));
    unawaited(
      _initStep(
        'background_tasks',
        BackgroundTaskService.initializeAndSchedule,
      ),
    );
    if (firebaseReady) {
      unawaited(
        _initStep('app_update_messaging', AppUpdateMessagingService.init),
      );
    }
  });
}

/// Runs one startup step, reporting failures instead of propagating them.
/// Returns whether the step succeeded.
Future<bool> _initStep(String name, Future<void> Function() step) async {
  try {
    await step();
    return true;
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('Startup step "$name" failed: $error');
    }
    unawaited(
      CrashReporting.captureException(
        error,
        stackTrace: stackTrace,
        hint: 'startup.$name',
        tags: {'startup_step': name},
      ),
    );
    return false;
  }
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
  bool _showSplash = true;
  bool _checkingAppUpdate = false;
  final AppUpdateService _appUpdateService = AppUpdateService();
  final Set<int> _promptedUpdateBuilds = <int>{};
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
      if (!_showSplash) {
        unawaited(_checkForAppUpdate());
      }
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
    unawaited(
      Analytics.track(
        'theme_toggled',
        properties: {'to': nextMode == ThemeMode.dark ? 'dark' : 'light'},
      ),
    );
  }

  bool get _isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> _checkForWidgetClick() async {
    Map<dynamic, dynamic>? result;
    try {
      result = await _widgetIntentChannel.invokeMethod<Map<dynamic, dynamic>?>(
        'consumeWidgetClick',
      );
    } on PlatformException catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Widget intent channel error: $error');
        debugPrint('$stackTrace');
      }
      return;
    } on MissingPluginException catch (error) {
      if (kDebugMode) {
        debugPrint('Widget intent channel missing plugin: $error');
      }
      return;
    }
    final target = WidgetClickTarget.fromPayload(result);
    if (target == null) {
      return;
    }
    unawaited(
      Analytics.track(
        'widget_tapped',
        properties: {'destination': target.destination.name},
      ),
    );
    await _openWidgetDestination(target);
  }

  Future<void> _openWidgetDestination(WidgetClickTarget target) async {
    final season = DateTime.now().year.toString();
    final api = ApiService();
    Widget? screen;
    try {
      switch (target.destination) {
        case WidgetDestination.favoriteDriverConfig:
        case WidgetDestination.favoriteTeamConfig:
          screen = WidgetConfigScreen(
            type: target.destination == WidgetDestination.favoriteTeamConfig
                ? WidgetConfigType.team
                : WidgetConfigType.driver,
            widgetId: target.widgetId,
            season: season,
          );
        case WidgetDestination.driverStandings:
          final snapshot = await api.getDriverStandingsSnapshot(season: season);
          screen = DriverStandingsScreen(
            standings: snapshot.data,
            season: season,
            lastUpdated: snapshot.lastUpdated,
            isFromCache: snapshot.isFromCache,
          );
        case WidgetDestination.teamStandings:
          final snapshot = await api.getConstructorStandingsSnapshot(
            season: season,
          );
          screen = ConstructorStandingsScreen(
            standings: snapshot.data,
            season: season,
            lastUpdated: snapshot.lastUpdated,
            isFromCache: snapshot.isFromCache,
          );
        case WidgetDestination.driverDetail:
          final standings = await api.getDriverStandings(season: season);
          final driver = standings
              .where((d) => d.driverId == target.targetId)
              .firstOrNull;
          if (driver != null) {
            screen = DriverDetailScreen(driver: driver, season: season);
          }
        case WidgetDestination.teamDetail:
          final standings = await api.getConstructorStandings(season: season);
          final team = standings
              .where((t) => t.constructorId == target.targetId)
              .firstOrNull;
          if (team != null) {
            screen = TeamDetailScreen(team: team, season: season);
          }
        case WidgetDestination.raceDetail:
          final race = await api.getNextRace(season: season);
          if (race != null) {
            screen = RaceDetailScreen(race: race, season: season);
          }
      }
    } catch (error, stackTrace) {
      // Offline with no cache: just leave the app on its home tab.
      if (kDebugMode) {
        debugPrint('Widget tap: failed to load ${target.destination}: $error');
        debugPrint('$stackTrace');
      }
    }
    final destination = screen;
    if (destination == null || !mounted) {
      return;
    }
    _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  void _runBackgroundChecks() {
    unawaited(FavoriteResultAlertService.checkForUpdates());
  }

  Future<void> _checkForAppUpdate() async {
    if (_checkingAppUpdate) {
      return;
    }
    _checkingAppUpdate = true;
    try {
      final notice = await _appUpdateService.checkForUpdate();
      if (!mounted || notice == null) {
        return;
      }
      if (!_promptedUpdateBuilds.add(notice.latestBuild)) {
        return;
      }
      final context = _navigatorKey.currentContext;
      if (context == null || !context.mounted) {
        return;
      }
      await _showAppUpdateDialog(context, notice);
    } finally {
      _checkingAppUpdate = false;
    }
  }

  Future<void> _showAppUpdateDialog(
    BuildContext context,
    AppUpdateNotice notice,
  ) async {
    final versionLabel = notice.latestVersion.isEmpty
        ? 'Build ${notice.latestBuild}'
        : 'Version ${notice.latestVersion}';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Update available'),
          content: Text('$versionLabel is ready.\n\n${notice.releaseNotes}'),
          actions: [
            TextButton(
              onPressed: () async {
                await _appUpdateService.dismiss(notice);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                unawaited(
                  launchUrl(
                    notice.storeUrl,
                    mode: LaunchMode.externalApplication,
                  ),
                );
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
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
      home: _showSplash
          ? SplashScreen(
              onComplete: () {
                if (mounted) {
                  setState(() {
                    _showSplash = false;
                  });
                  unawaited(_checkForAppUpdate());
                }
              },
            )
          : MainShell(isDarkMode: _isDarkMode, onToggleTheme: _toggleTheme),
    );
  }
}
