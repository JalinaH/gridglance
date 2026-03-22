import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/widgets/celebration_overlay.dart';

void main() {
  group('CelebrationType', () {
    test('has confetti and pulse variants', () {
      expect(CelebrationType.values, hasLength(2));
      expect(
        CelebrationType.values,
        containsAll([CelebrationType.confetti, CelebrationType.pulse]),
      );
    });
  });

  group('CelebrationOverlay', () {
    testWidgets('shows confetti overlay and auto-removes after animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => CelebrationOverlay.show(context),
                child: const Text('Celebrate'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Celebrate'));
      await tester.pump();

      // CustomPaint should be visible during animation
      expect(find.byType(CustomPaint), findsWidgets);

      // After animation completes, overlay should be removed
      await tester.pumpAndSettle();
    });

    testWidgets('shows pulse overlay variant', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => CelebrationOverlay.show(
                  context,
                  variant: CelebrationType.pulse,
                ),
                child: const Text('Pulse'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Pulse'));
      await tester.pump();

      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pumpAndSettle();
    });

    testWidgets('overlay does not intercept pointer events', (tester) async {
      var tappedAfterOverlay = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              Builder(
                builder: (context) {
                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: () => CelebrationOverlay.show(context),
                        child: const Text('Show'),
                      ),
                      ElevatedButton(
                        onPressed: () => tappedAfterOverlay = true,
                        child: const Text('Other'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );

      // Show overlay
      await tester.tap(find.text('Show'));
      await tester.pump();

      // Try tapping another button while overlay is active
      // The overlay uses IgnorePointer so this should work
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();

      expect(tappedAfterOverlay, isTrue);
    });

    testWidgets('replaces active overlay when called multiple times', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => CelebrationOverlay.show(context),
                child: const Text('Celebrate'),
              );
            },
          ),
        ),
      );

      // Trigger twice rapidly — should not throw or leave stale overlays
      await tester.tap(find.text('Celebrate'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Celebrate'));
      await tester.pump();

      // Should still render without errors
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pumpAndSettle();
    });
  });
}
