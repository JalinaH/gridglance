import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/theme/app_theme.dart';
import 'package:gridglance/widgets/compact_search_field.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('CompactSearchField', () {
    testWidgets('renders with hint text', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrapWithTheme(
          CompactSearchField(
            controller: controller,
            onChanged: (_) {},
            hintText: 'Search drivers',
          ),
        ),
      );

      expect(find.text('Search drivers'), findsOneWidget);
      controller.dispose();
    });

    testWidgets('shows search icon', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrapWithTheme(
          CompactSearchField(
            controller: controller,
            onChanged: (_) {},
            hintText: 'Search',
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
      controller.dispose();
    });

    testWidgets('calls onChanged when text is entered', (tester) async {
      final controller = TextEditingController();
      String? changedValue;
      await tester.pumpWidget(
        _wrapWithTheme(
          CompactSearchField(
            controller: controller,
            onChanged: (value) => changedValue = value,
            hintText: 'Search',
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'test query');
      expect(changedValue, 'test query');
      controller.dispose();
    });

    testWidgets('shows clear button when onClear is provided', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'some text');
      await tester.pumpWidget(
        _wrapWithTheme(
          CompactSearchField(
            controller: controller,
            onChanged: (_) {},
            hintText: 'Search',
            onClear: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
      controller.dispose();
    });

    testWidgets('does not show clear button when onClear is null', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrapWithTheme(
          CompactSearchField(
            controller: controller,
            onChanged: (_) {},
            hintText: 'Search',
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsNothing);
      controller.dispose();
    });

    testWidgets('calls onClear when clear button tapped', (tester) async {
      final controller = TextEditingController(text: 'query');
      var cleared = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          CompactSearchField(
            controller: controller,
            onChanged: (_) {},
            hintText: 'Search',
            onClear: () => cleared = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(cleared, isTrue);
      controller.dispose();
    });

    testWidgets('has rounded container decoration', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrapWithTheme(
          CompactSearchField(
            controller: controller,
            onChanged: (_) {},
            hintText: 'Search',
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byType(TextField),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(14));
      controller.dispose();
    });
  });
}
