import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/widgets/animated_counter.dart';

void main() {
  group('AnimatedCounter', () {
    testWidgets('starts at zero and animates to target value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AnimatedCounter(value: 100)),
      );

      // At start, text should show 0
      expect(find.text('0'), findsOneWidget);

      // After animation completes, should show final value
      await tester.pumpAndSettle();
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('displays prefix and suffix', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnimatedCounter(value: 42, prefix: 'P', suffix: ' pts'),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('P42 pts'), findsOneWidget);
    });

    testWidgets('formats decimal places correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AnimatedCounter(value: 3.5, decimalPlaces: 1)),
      );

      await tester.pumpAndSettle();
      expect(find.text('3.5'), findsOneWidget);
    });

    testWidgets('rounds integer values with zero decimal places', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: AnimatedCounter(value: 7.9, decimalPlaces: 0)),
      );

      await tester.pumpAndSettle();
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('applies custom TextStyle', (tester) async {
      const style = TextStyle(fontSize: 24, color: Colors.red);
      await tester.pumpWidget(
        const MaterialApp(home: AnimatedCounter(value: 50, style: style)),
      );

      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.text('50'));
      expect(text.style?.fontSize, 24);
      expect(text.style?.color, Colors.red);
    });

    testWidgets('applies textAlign', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnimatedCounter(value: 10, textAlign: TextAlign.center),
        ),
      );

      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.text('10'));
      expect(text.textAlign, TextAlign.center);
    });

    testWidgets('handles zero value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AnimatedCounter(value: 0)),
      );

      await tester.pumpAndSettle();
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('shows intermediate values during animation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnimatedCounter(
            value: 200,
            duration: Duration(milliseconds: 800),
          ),
        ),
      );

      // Advance partway through animation
      await tester.pump(const Duration(milliseconds: 400));

      // Find the Text widget and check its value is between 0 and 200
      final textFinder = find.byType(Text);
      final text = tester.widget<Text>(textFinder);
      final displayedValue = int.tryParse(text.data ?? '');
      expect(displayedValue, isNotNull);
      expect(displayedValue, greaterThan(0));
      expect(displayedValue, lessThanOrEqualTo(200));
    });
  });
}
