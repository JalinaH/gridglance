import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stored app theme choice: follow the system, or always light or dark.
class ThemePreference {
  ThemePreference._();

  static const String _key = 'theme_mode';

  /// Dark stays the default, as it was before "system" existed.
  static Future<ThemeMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_key)) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  static Future<void> save(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
