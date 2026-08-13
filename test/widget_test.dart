import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/main.dart';
import 'package:quran_memorization/memorization_calc.dart';

/// The results card sits below the fold in the 800x600 test viewport and the
/// ListView builds children lazily, so tests must scroll to it.
Future<void> scrollToResults(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  testWidgets('app renders inputs and a live finish date', (tester) async {
    await tester.pumpWidget(const QuranMemorizationApp());

    // Inputs present (the list is lazy, so scroll to the lower sections).
    expect(find.text('Current page'), findsOneWidget);
    expect(find.text('Daily memorization'), findsOneWidget);
    await scrollToResults(tester, find.text('Rest days'));
    expect(find.text('Rest days'), findsOneWidget);

    // Defaults: page 1, 10 lines/day → 604 * 15 / 10 = 906 study sessions.
    final plan = MemorizationPlan.fromLinesPerDay(
      currentPage: 1,
      linesPerDay: 10,
    );
    final expected = plan.compute();
    await scrollToResults(tester, find.text(formatDate(expected.finishDate)));
    expect(find.text(formatDate(expected.finishDate)), findsOneWidget);
    // Study sessions and calendar days are both 906 when memorizing daily.
    expect(find.text('906'), findsNWidgets(2));
  });

  testWidgets('changing the page updates the result', (tester) async {
    await tester.pumpWidget(const QuranMemorizationApp());

    // Jump to page 604: only 1 page remains.
    await tester.enterText(find.byType(TextField).first, '604');
    await tester.pump();

    await scrollToResults(tester, find.text('1 pages'));
    expect(find.text('1 pages'), findsOneWidget);
    expect(find.textContaining('today'), findsWidgets);
  });

  testWidgets('invalid rate shows guidance instead of a date', (tester) async {
    await tester.pumpWidget(const QuranMemorizationApp());

    await tester.enterText(find.byType(TextField).at(1), '0');
    await tester.pump();

    await scrollToResults(tester, find.textContaining('Fill in a valid page'));
    expect(find.textContaining('Fill in a valid page'), findsOneWidget);
  });

  testWidgets(
    'switching to last-page mode starts at page 604 and plans backward',
    (tester) async {
      await tester.pumpWidget(const QuranMemorizationApp());

      // Default forward mode starts at page 1.
      expect(find.widgetWithText(TextField, '1'), findsOneWidget);

      await tester.tap(find.text('From the last page'));
      await tester.pumpAndSettle();

      // The page field jumps to the last page: whole mushaf remains.
      expect(find.widgetWithText(TextField, '604'), findsOneWidget);
      await scrollToResults(tester, find.text('604 pages'));
      expect(find.text('604 pages'), findsOneWidget);
      expect(
        find.textContaining('From the last page · memorizing 604 → 1'),
        findsOneWidget,
      );
      // 10 lines/day ≈ ⅔ page/day → 906 study sessions, same as forward.
      expect(find.text('906'), findsNWidgets(2));
    },
  );

  testWidgets('switching back to first-page mode returns to page 1', (
    tester,
  ) async {
    await tester.pumpWidget(const QuranMemorizationApp());

    await tester.tap(find.text('From the last page'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '604'), findsOneWidget);

    await tester.tap(find.text('From the first page'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '1'), findsOneWidget);
  });
}
