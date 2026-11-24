import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/screens/settings_screen.dart';
import 'package:gridglance/services/analytics.dart';
import 'package:gridglance/services/notification_preferences.dart';
import 'package:gridglance/services/user_preferences.dart';
import 'package:gridglance/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  Future<List<ThemeMode>> pumpSettings(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.dark,
  }) async {
    final changes = <ThemeMode>[];
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: SettingsScreen(
          themeMode: themeMode,
          onThemeModeChanged: changes.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return changes;
  }

  Switch switchFor(WidgetTester tester, String title) {
    final row = find.ancestor(of: find.text(title), matching: find.byType(Row));
    return tester.widget<Switch>(
      find.descendant(of: row.first, matching: find.byType(Switch)),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserPreferences.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async => true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
  });

  testWidgets('shows every section', (tester) async {
    await pumpSettings(tester);

    for (final text in [
      'APPEARANCE',
      'NOTIFICATIONS',
      'PRIVACY',
      'Theme',
      'Favorite session results',
      'Favorite standings changes',
      'Default reminder time',
      'Send anonymous usage data',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('picking a theme reports it', (tester) async {
    final changes = await pumpSettings(tester);

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    expect(changes, [ThemeMode.system, ThemeMode.light]);
  });

  testWidgets('picking the current theme does nothing', (tester) async {
    final changes = await pumpSettings(tester, themeMode: ThemeMode.dark);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(changes, isEmpty);
  });

  testWidgets('saves the default reminder time', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('1 hour'));
    await tester.pumpAndSettle();

    expect(await NotificationPreferences.getDefaultLeadTimeMinutes(), 60);
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '1 hour'),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('loads and turns on a favorite alert', (tester) async {
    SharedPreferences.setMockInitialValues({
      'favorite_driver_id': 'norris',
      'notify_favorite_position_points': true,
    });
    await pumpSettings(tester);

    expect(switchFor(tester, 'Favorite standings changes').value, isTrue);
    expect(switchFor(tester, 'Favorite session results').value, isFalse);

    await tester.tap(
      find.descendant(
        of: find
            .ancestor(
              of: find.text('Favorite session results'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      await NotificationPreferences.isFavoriteSessionFinishedEnabled(),
      isTrue,
    );
    expect(switchFor(tester, 'Favorite session results').value, isTrue);
  });

  testWidgets('hints at picking a favorite when there is none', (tester) async {
    await pumpSettings(tester);

    expect(find.textContaining('Pick a favorite driver or team'), findsOne);
  });

  testWidgets('no hint once a favorite is set', (tester) async {
    SharedPreferences.setMockInitialValues({'favorite_team_id': 'mclaren'});
    await pumpSettings(tester);

    expect(find.textContaining('Pick a favorite driver or team'), findsNothing);
  });

  testWidgets('turning off usage data opts out', (tester) async {
    await Analytics.setOptOut(false);
    await pumpSettings(tester);

    await tester.tap(
      find.descendant(
        of: find
            .ancestor(
              of: find.text('Send anonymous usage data'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();

    expect(Analytics.isOptedOut, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('analytics_opt_out'), isTrue);
    await Analytics.setOptOut(false);
  });

  test('labels each reminder preset', () {
    expect(
      NotificationPreferences.leadTimePresets.map(
        SettingsScreenLabels.leadTime,
      ),
      ['5 min', '15 min', '1 hour', '1 day'],
    );
  });
}
