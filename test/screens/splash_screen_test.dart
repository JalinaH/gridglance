import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/screens/splash_screen.dart';

void main() {
  group('SplashScreen', () {
    Future<void> pumpSplash(
      WidgetTester tester, {
      VoidCallback? onComplete,
    }) async {
      await tester.pumpWidget(
        MaterialApp(home: SplashScreen(onComplete: onComplete ?? () {})),
      );
    }

    /// Advances through the full animation sequence (3.5s total)
    /// and disposes cleanly by replacing the widget.
    Future<void> advanceAndDispose(WidgetTester tester) async {
      // Advance through: 200 + 500 + 300 + 800 + 1200 + 500 = 3500ms
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // Replace widget to stop repeating glow controller
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    }

    testWidgets('renders with a Scaffold', (tester) async {
      await pumpSplash(tester);

      expect(find.byType(Scaffold), findsOneWidget);

      await advanceAndDispose(tester);
    });

    testWidgets('displays app name text after animation progresses', (
      tester,
    ) async {
      await pumpSplash(tester);

      // Advance past initial delay + logo + glow + lights + text start
      for (int i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('GRIDGLANCE'), findsOneWidget);
      expect(find.text('YOUR F1 COMPANION'), findsOneWidget);

      await advanceAndDispose(tester);
    });

    testWidgets('renders 5 starting light indicators', (tester) async {
      await pumpSplash(tester);

      // Advance past lights animation start
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // The 5 lights are rendered as decorated Containers in a Row
      final rows = find.byType(Row);
      bool foundLightsRow = false;
      for (final element in rows.evaluate()) {
        final widget = element.widget as Row;
        if (widget.children.length == 5) {
          foundLightsRow = true;
          break;
        }
      }
      expect(foundLightsRow, isTrue);

      await advanceAndDispose(tester);
    });

    testWidgets('contains CustomPaint for racing stripes', (tester) async {
      await pumpSplash(tester);

      // Advance to where stripes are painting
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(CustomPaint), findsWidgets);

      await advanceAndDispose(tester);
    });

    testWidgets('logo starts hidden and fades in', (tester) async {
      await pumpSplash(tester);

      // Before logo animation starts (within initial 200ms delay)
      await tester.pump(const Duration(milliseconds: 50));

      // Find Opacity widgets — the logo should be present
      expect(find.byType(Opacity), findsWidgets);

      // Advance past logo animation
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      await advanceAndDispose(tester);
    });

    testWidgets('calls onComplete after full animation sequence', (
      tester,
    ) async {
      var completed = false;

      await pumpSplash(tester, onComplete: () => completed = true);

      expect(completed, isFalse);

      // Advance through full sequence: 200+500+300+800+1200+500 = 3500ms
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(completed, isTrue);

      // Replace widget to clean up repeating controller
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    });

    testWidgets('has dark background color', (tester) async {
      await pumpSplash(tester);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF0C0F14));

      await advanceAndDispose(tester);
    });

    testWidgets('disposes without errors', (tester) async {
      await pumpSplash(tester);

      // Advance through all pending timers before disposing
      await advanceAndDispose(tester);

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
