import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/theme/app_theme.dart';
import 'package:gridglance/widgets/swipe_action_wrapper.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(
      useMaterial3: true,
    ).copyWith(extensions: [AppTheme.darkColors]),
    home: Scaffold(body: child),
  );
}

void main() {
  group('SwipeActionWrapper', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          SwipeActionWrapper(
            icon: Icons.favorite,
            label: 'Favorite',
            onSwipe: () {},
            child: const ListTile(title: Text('Driver')),
          ),
        ),
      );

      expect(find.text('Driver'), findsOneWidget);
    });

    testWidgets('triggers primary action on right swipe past threshold', (
      tester,
    ) async {
      var swiped = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          SwipeActionWrapper(
            icon: Icons.favorite,
            label: 'Favorite',
            onSwipe: () => swiped = true,
            child: const SizedBox(
              width: 300,
              height: 60,
              child: Text('Swipe me'),
            ),
          ),
        ),
      );

      // Swipe right past the 80px threshold
      await tester.drag(find.text('Swipe me'), const Offset(120, 0));
      await tester.pumpAndSettle();

      expect(swiped, isTrue);
    });

    testWidgets('does not trigger primary action if swipe is below threshold', (
      tester,
    ) async {
      var swiped = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          SwipeActionWrapper(
            icon: Icons.favorite,
            label: 'Favorite',
            onSwipe: () => swiped = true,
            child: const SizedBox(
              width: 300,
              height: 60,
              child: Text('Swipe me'),
            ),
          ),
        ),
      );

      // Swipe less than threshold
      await tester.drag(find.text('Swipe me'), const Offset(40, 0));
      await tester.pumpAndSettle();

      expect(swiped, isFalse);
    });

    testWidgets('triggers secondary action on left swipe past threshold', (
      tester,
    ) async {
      var primarySwiped = false;
      var secondarySwiped = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          SwipeActionWrapper(
            icon: Icons.favorite,
            label: 'Favorite',
            onSwipe: () => primarySwiped = true,
            secondaryIcon: Icons.star,
            secondaryLabel: 'Star',
            onSecondarySwipe: () => secondarySwiped = true,
            child: const SizedBox(
              width: 300,
              height: 60,
              child: Text('Swipe me'),
            ),
          ),
        ),
      );

      // Swipe left past threshold
      await tester.drag(find.text('Swipe me'), const Offset(-120, 0));
      await tester.pumpAndSettle();

      expect(primarySwiped, isFalse);
      expect(secondarySwiped, isTrue);
    });

    testWidgets('prevents left swipe when no secondary action is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          SwipeActionWrapper(
            icon: Icons.favorite,
            label: 'Favorite',
            onSwipe: () {},
            child: const SizedBox(
              width: 300,
              height: 60,
              child: Text('Swipe me'),
            ),
          ),
        ),
      );

      // Try swiping left — should not move
      await tester.drag(find.text('Swipe me'), const Offset(-120, 0));
      await tester.pumpAndSettle();

      // Widget should still be at original position (no crash)
      expect(find.text('Swipe me'), findsOneWidget);
    });

    testWidgets('shows primary label during right swipe', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          SwipeActionWrapper(
            icon: Icons.favorite,
            label: 'Favorite',
            onSwipe: () {},
            child: const SizedBox(
              width: 300,
              height: 60,
              child: Text('Swipe me'),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Swipe me')),
      );
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();

      expect(find.text('Favorite'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('returns to original position after swipe', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          SwipeActionWrapper(
            icon: Icons.favorite,
            label: 'Favorite',
            onSwipe: () {},
            child: const SizedBox(
              width: 300,
              height: 60,
              child: Text('Swipe me'),
            ),
          ),
        ),
      );

      await tester.drag(find.text('Swipe me'), const Offset(100, 0));
      await tester.pumpAndSettle();

      // After settling, child should be back at origin
      expect(find.text('Swipe me'), findsOneWidget);
    });
  });
}
