import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/main.dart';
import 'package:quran_memorization/memorization_calc.dart';
import 'package:quran_memorization/services/memorization_log.dart';
import 'package:quran_memorization/services/planner_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('planner restores persisted page and rate', (tester) async {
    await tester.pumpWidget(
      const QuranMemorizationApp(
        plannerSettings: PlannerSettings(page: 42, rate: 5),
      ),
    );
    await tester.pump();

    expect(find.widgetWithText(TextField, '42'), findsOneWidget);
    expect(find.widgetWithText(TextField, '5'), findsOneWidget);
  });

  testWidgets('marking today done updates the card and undoes', (tester) async {
    await tester.pumpWidget(const QuranMemorizationApp());
    await tester.pump();

    await scrollTo(tester, find.text('Mark today’s portion done'));
    expect(find.text('Mark today’s portion done'), findsOneWidget);
    expect(find.textContaining('day streak'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('mark-done')));
    await tester.pumpAndSettle();

    expect(find.text('Done today — barakallahu feek!'), findsOneWidget);
    await scrollTo(tester, find.text('day streak'));
    expect(find.text('day streak'), findsOneWidget);

    // Undo removes the session.
    await tester.tap(find.byKey(const ValueKey('undo-today')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Mark today’s portion done'));
    expect(find.text('Mark today’s portion done'), findsOneWidget);
  });

  testWidgets('a pre-existing session shows the streak and history', (
    tester,
  ) async {
    final today = DateTime.now();
    final yesterday = DateTime(
      today.year,
      today.month,
      today.day - 1,
    );
    var log = MemorizationLog();
    log = log.record(
      date: yesterday,
      page: 7,
      lines: 10,
      direction: MemorizationDirection.forward,
    );
    await tester.pumpWidget(QuranMemorizationApp(log: log));
    await tester.pump();

    await scrollTo(tester, find.text('day streak'));
    expect(find.text('1'), findsWidgets); // streak of 1
    expect(find.textContaining('yesterday'), findsOneWidget);
  });

  testWidgets('theme toggle switches to dark mode', (tester) async {
    await tester.pumpWidget(const QuranMemorizationApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(PlannerScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('start date row shows today and opens the date picker', (
    tester,
  ) async {
    await tester.pumpWidget(const QuranMemorizationApp());
    await tester.pump();

    expect(find.text('Plan starts'), findsOneWidget);
    expect(find.textContaining('Today ('), findsOneWidget);

    await tester.tap(find.text('Change date'));
    await tester.pumpAndSettle();
    expect(find.text('When does your plan start?'), findsOneWidget);
  });

  testWidgets('a persisted dark theme is applied at startup', (tester) async {
    await tester.pumpWidget(
      const QuranMemorizationApp(
        plannerSettings: PlannerSettings(themeMode: ThemeMode.dark),
      ),
    );
    await tester.pump();

    final context = tester.element(find.byType(PlannerScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('typing in the planner saves the inputs to preferences', (
    tester,
  ) async {
    await tester.pumpWidget(const QuranMemorizationApp());
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '33');
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), '4');
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('plan.page'), 33);
    expect(prefs.getDouble('plan.rate'), 4);
  });

  testWidgets('marking done saves the session to preferences', (tester) async {
    await tester.pumpWidget(const QuranMemorizationApp());
    await tester.pump();

    await scrollTo(tester, find.byKey(const ValueKey('mark-done')));
    await tester.tap(find.byKey(const ValueKey('mark-done')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('log.sessions');
    expect(stored, isNotNull);
    expect(stored!.length, 1);
    expect(stored.first, contains('|1|')); // page 1
    expect(stored.first, contains('|forward'));
  });
}
