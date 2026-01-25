import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
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
    final nextMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GridGlance',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: MainShell(
        isDarkMode: _isDarkMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
