import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/services/theme_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ThemePreference', () {
    test('defaults to dark, as before "system" existed', () async {
      SharedPreferences.setMockInitialValues({});

      expect(await ThemePreference.load(), ThemeMode.dark);
    });

    test('reads values saved by older builds', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      expect(await ThemePreference.load(), ThemeMode.light);

      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      expect(await ThemePreference.load(), ThemeMode.dark);
    });

    test('round-trips every mode', () async {
      SharedPreferences.setMockInitialValues({});
      for (final mode in ThemeMode.values) {
        await ThemePreference.save(mode);
        expect(await ThemePreference.load(), mode);
      }
    });

    test('treats an unknown value as dark', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});

      expect(await ThemePreference.load(), ThemeMode.dark);
    });
  });
}
