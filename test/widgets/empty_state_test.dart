import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/theme/app_theme.dart';
import 'package:gridglance/widgets/empty_state.dart';

/// Wraps a widget with MaterialApp and the required AppColors theme extension.
Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(
      useMaterial3: true,
    ).copyWith(extensions: [AppTheme.darkColors]),
    home: Scaffold(body: child),
  );
}

void main() {
  group('EmptyState', () {
    testWidgets('displays the message text', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(const EmptyState(message: 'No standings available')),
      );

      expect(find.text('No standings available'), findsOneWidget);
    });

    testWidgets('centers the message text', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(const EmptyState(message: 'Empty')),
      );

      final text = tester.widget<Text>(find.text('Empty'));
      expect(text.textAlign, TextAlign.center);
    });

    testWidgets('shows leaderboard icon for standings type', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const EmptyState(
            message: 'No standings',
            type: EmptyStateType.standings,
          ),
        ),
      );

      expect(find.byIcon(Icons.leaderboard_outlined), findsOneWidget);
    });

    testWidgets('shows flag icon for race type', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const EmptyState(message: 'No race', type: EmptyStateType.race),
        ),
      );

      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    });

    testWidgets('shows trophy icon for results type', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const EmptyState(message: 'No results', type: EmptyStateType.results),
        ),
      );

      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
    });

    testWidgets('shows calendar icon for schedule type', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const EmptyState(
            message: 'No schedule',
            type: EmptyStateType.schedule,
          ),
        ),
      );

      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    });

    testWidgets('shows brain icon for predictions type', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const EmptyState(
            message: 'No predictions',
            type: EmptyStateType.predictions,
          ),
        ),
      );

      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
    });

    testWidgets('shows cloud_off icon for network type', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const EmptyState(
            message: 'No connection',
            type: EmptyStateType.network,
          ),
        ),
      );

      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });

    testWidgets('shows grid icon for generic type', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const EmptyState(
            message: 'Nothing here',
            type: EmptyStateType.generic,
          ),
        ),
      );

      expect(find.byIcon(Icons.grid_view_outlined), findsOneWidget);
    });

    testWidgets('defaults to generic type', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(const EmptyState(message: 'Default')),
      );

      expect(find.byIcon(Icons.grid_view_outlined), findsOneWidget);
    });

    testWidgets('renders icon inside a circular container', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(const EmptyState(message: 'Test')),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
    });
  });

  group('EmptyStateType', () {
    test('has all expected variants', () {
      expect(EmptyStateType.values, hasLength(7));
      expect(
        EmptyStateType.values,
        containsAll([
          EmptyStateType.standings,
          EmptyStateType.race,
          EmptyStateType.results,
          EmptyStateType.schedule,
          EmptyStateType.predictions,
          EmptyStateType.network,
          EmptyStateType.generic,
        ]),
      );
    });
  });
}
