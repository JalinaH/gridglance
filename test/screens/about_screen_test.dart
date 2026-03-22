import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/screens/about_screen.dart';
import 'package:gridglance/theme/app_theme.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('AboutScreen', () {
    testWidgets('renders app name', (tester) async {
      await tester.pumpWidget(_wrapWithTheme(const AboutScreen()));
      await tester.pump();

      expect(find.text('GridGlance'), findsOneWidget);
    });

    testWidgets('renders GG icon text', (tester) async {
      await tester.pumpWidget(_wrapWithTheme(const AboutScreen()));
      await tester.pump();

      expect(find.text('GG'), findsOneWidget);
    });

    testWidgets('renders description text', (tester) async {
      await tester.pumpWidget(_wrapWithTheme(const AboutScreen()));
      await tester.pump();

      expect(
        find.text(
          'Your Formula 1 companion.\nStandings, schedules & results at a glance.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders FEATURES section header', (tester) async {
      await tester.pumpWidget(_wrapWithTheme(const AboutScreen()));
      await tester.pump();

      expect(find.text('FEATURES'), findsOneWidget);
    });

    testWidgets('renders all feature rows', (tester) async {
      await tester.pumpWidget(_wrapWithTheme(const AboutScreen()));
      await tester.pump();

      expect(find.text('Live Standings'), findsOneWidget);
      expect(find.text('Race Calendar'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Home Widgets'), findsOneWidget);

      // Last features may be off-screen, scroll to reveal
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Share Cards'),
        200,
        scrollable: scrollable,
      );
      expect(find.text('Race Weather'), findsOneWidget);
      expect(find.text('Share Cards'), findsOneWidget);
    });

    testWidgets('renders INFO section with data sources', (tester) async {
      await tester.pumpWidget(_wrapWithTheme(const AboutScreen()));
      await tester.pump();

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('INFO'),
        200,
        scrollable: scrollable,
      );

      expect(find.text('INFO'), findsOneWidget);
      expect(find.text('Data Source'), findsOneWidget);
      expect(find.text('Jolpica F1 API (Ergast)'), findsOneWidget);
      expect(find.text('Weather Data'), findsOneWidget);
      expect(find.text('Open-Meteo'), findsOneWidget);
    });

    testWidgets('does not render Season info card', (tester) async {
      await tester.pumpWidget(_wrapWithTheme(const AboutScreen()));
      await tester.pump();

      expect(find.text('Season'), findsNothing);
      expect(
        find.text('2025 Formula 1 World Championship'),
        findsNothing,
      );
    });

    testWidgets('renders LINKS section header', (tester) async {
      await tester.pumpWidget(_wrapWithTheme(const AboutScreen()));
      await tester.pump();

      // Scroll down to make LINKS visible
      await tester.scrollUntilVisible(
        find.text('LINKS'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('LINKS'), findsOneWidget);
    });

    testWidgets('renders all link titles', (tester) async {
      await tester.pumpWidget(_wrapWithTheme(const AboutScreen()));
      await tester.pump();

      // Scroll to bottom to reveal all links
      await tester.scrollUntilVisible(
        find.text('Send Feedback'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Rate on Play Store'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Send Feedback'), findsOneWidget);
    });

    testWidgets('renders footer with copyright', (tester) async {
      await tester.pumpWidget(_wrapWithTheme(const AboutScreen()));
      await tester.pump();

      // Scroll to bottom
      await tester.scrollUntilVisible(
        find.text('Made with passion for F1 fans'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Made with passion for F1 fans'), findsOneWidget);
      expect(
        find.text('\u00a9 ${DateTime.now().year} GridGlance'),
        findsOneWidget,
      );
    });

    testWidgets('is scrollable (uses ListView)', (tester) async {
      await tester.pumpWidget(_wrapWithTheme(const AboutScreen()));
      await tester.pump();

      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
