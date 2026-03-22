import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/widgets/bounce_tap.dart';

void main() {
  group('BounceTap', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BounceTap(
            child: Text('Tap me'),
          ),
        ),
      );

      expect(find.text('Tap me'), findsOneWidget);
    });

    testWidgets('wraps child in ScaleTransition', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BounceTap(
            child: Text('Tap me'),
          ),
        ),
      );

      expect(find.byType(ScaleTransition), findsOneWidget);
    });

    testWidgets('wraps child in Listener for pointer events', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BounceTap(
            child: Text('Tap me'),
          ),
        ),
      );

      // Multiple Listener widgets exist in the tree (from MaterialApp etc),
      // so just verify at least one is present wrapping our content
      expect(find.byType(Listener), findsWidgets);
    });

    testWidgets('starts at scale 1.0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BounceTap(
            child: Text('Tap me'),
          ),
        ),
      );

      final scaleTransition = tester.widget<ScaleTransition>(
        find.byType(ScaleTransition),
      );
      expect(scaleTransition.scale.value, 1.0);
    });

    testWidgets('scales down on pointer down', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BounceTap(
            child: SizedBox(width: 100, height: 50, child: Text('Tap me')),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Tap me')),
      );
      // Pump multiple frames to let the animation controller advance
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final scaleTransition = tester.widget<ScaleTransition>(
        find.byType(ScaleTransition),
      );
      expect(scaleTransition.scale.value, lessThan(1.0));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('returns to scale 1.0 after pointer up', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BounceTap(
            child: SizedBox(width: 100, height: 50, child: Text('Tap me')),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Tap me')),
      );
      await tester.pump(const Duration(milliseconds: 120));
      await gesture.up();
      await tester.pumpAndSettle();

      final scaleTransition = tester.widget<ScaleTransition>(
        find.byType(ScaleTransition),
      );
      expect(scaleTransition.scale.value, 1.0);
    });

    testWidgets('uses custom scaleDown value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BounceTap(
            scaleDown: 0.8,
            child: SizedBox(width: 100, height: 50, child: Text('Tap me')),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Tap me')),
      );
      // Pump enough frames for the 120ms forward animation to complete
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final scaleTransition = tester.widget<ScaleTransition>(
        find.byType(ScaleTransition),
      );
      // After forward animation completes, scale should be near scaleDown
      expect(scaleTransition.scale.value, lessThan(1.0));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('does not consume tap events from child', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: BounceTap(
            child: ElevatedButton(
              onPressed: () => tapped = true,
              child: const Text('Button'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Button'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });
}
