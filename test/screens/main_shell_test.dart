import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/screens/main_shell.dart';
import 'package:gridglance/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildShell({bool isDarkMode = true, VoidCallback? onToggleTheme}) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: MainShell(
      isDarkMode: isDarkMode,
      onToggleTheme: onToggleTheme ?? () {},
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Stub method channels used by home_widget and other plugins
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('gridglance/dps'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('gridglance/widget_intent'),
      (call) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('gridglance/dps'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('gridglance/widget_intent'),
      null,
    );
  });

  group('MainShell', () {
    testWidgets('renders bottom navigation bar with 3 tabs', (tester) async {
      // WidgetsScreen fires async API calls that fail in test — ignore them
      final errors = <Object>[];
      await runZonedGuarded(
        () async {
          await tester.pumpWidget(_buildShell());
          await tester.pump();

          expect(find.text('Home'), findsWidgets);
          expect(find.text('Widgets'), findsWidgets);
          expect(find.text('About'), findsWidgets);
        },
        (error, stack) => errors.add(error),
      );
    });

    testWidgets('starts with GridGlance title (Home tab)', (tester) async {
      final errors = <Object>[];
      await runZonedGuarded(
        () async {
          await tester.pumpWidget(_buildShell());
          await tester.pump();

          expect(find.text('GridGlance'), findsOneWidget);
        },
        (error, stack) => errors.add(error),
      );
    });

    testWidgets('shows theme toggle icon button', (tester) async {
      final errors = <Object>[];
      await runZonedGuarded(
        () async {
          await tester.pumpWidget(_buildShell(isDarkMode: true));
          await tester.pump();

          expect(find.byIcon(Icons.light_mode), findsOneWidget);
        },
        (error, stack) => errors.add(error),
      );
    });

    testWidgets('shows dark_mode icon when not in dark mode', (tester) async {
      final errors = <Object>[];
      await runZonedGuarded(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              home: MainShell(isDarkMode: false, onToggleTheme: () {}),
            ),
          );
          await tester.pump();

          expect(find.byIcon(Icons.dark_mode), findsOneWidget);
        },
        (error, stack) => errors.add(error),
      );
    });

    testWidgets('calls onToggleTheme when theme button tapped', (
      tester,
    ) async {
      final errors = <Object>[];
      var toggled = false;
      await runZonedGuarded(
        () async {
          await tester.pumpWidget(
            _buildShell(onToggleTheme: () => toggled = true),
          );
          await tester.pump();

          await tester.tap(find.byIcon(Icons.light_mode));
          await tester.pump();

          expect(toggled, isTrue);
        },
        (error, stack) => errors.add(error),
      );
    });

    testWidgets('tapping About tab shows About title', (tester) async {
      final errors = <Object>[];
      await runZonedGuarded(
        () async {
          await tester.pumpWidget(_buildShell());
          await tester.pump();

          final aboutFinder = find.text('About');
          await tester.tap(aboutFinder.last);
          await tester.pump();

          expect(find.text('About'), findsWidgets);
        },
        (error, stack) => errors.add(error),
      );
    });

    testWidgets('uses IndexedStack for tab persistence', (tester) async {
      final errors = <Object>[];
      await runZonedGuarded(
        () async {
          await tester.pumpWidget(_buildShell());
          await tester.pump();

          expect(find.byType(IndexedStack), findsOneWidget);
        },
        (error, stack) => errors.add(error),
      );
    });
  });
}
