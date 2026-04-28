import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/theme/app_theme.dart';
import 'package:gridglance/widgets/f1_scaffold.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(theme: AppTheme.dark(), home: child);
}

void main() {
  group('F1Scaffold', () {
    testWidgets('renders body content', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(const F1Scaffold(body: Text('Hello F1'))),
      );

      expect(find.text('Hello F1'), findsOneWidget);
    });

    testWidgets('renders with an AppBar when provided', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          F1Scaffold(
            appBar: AppBar(title: const Text('Test Title')),
            body: const Text('Body'),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
    });

    testWidgets('renders without an AppBar when not provided', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(const F1Scaffold(body: Text('No AppBar'))),
      );

      expect(find.text('No AppBar'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('renders floating action button when provided', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          F1Scaffold(
            body: const Text('FAB test'),
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('wraps body in ConstrainedBox when maxContentWidth set', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const F1Scaffold(body: Text('Constrained'), maxContentWidth: 600),
        ),
      );

      // ConstrainedBox wraps the body content
      final constrainedBoxes = find.byType(ConstrainedBox);
      expect(constrainedBoxes, findsWidgets);
      expect(find.text('Constrained'), findsOneWidget);
    });

    testWidgets('uses transparent scaffold background', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(const F1Scaffold(body: Text('Transparent'))),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.transparent);
    });

    testWidgets('extends body behind app bar', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          F1Scaffold(
            appBar: AppBar(title: const Text('Title')),
            body: const Text('Extended'),
          ),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBodyBehindAppBar, isTrue);
    });

    testWidgets('contains background decoration with CustomPaint or Stack', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithTheme(const F1Scaffold(body: Text('Background'))),
      );

      // F1Scaffold uses a Stack with _F1Background
      expect(find.byType(Stack), findsWidgets);
    });
  });
}
