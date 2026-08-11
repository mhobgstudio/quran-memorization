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

    // Inputs present.
    expect(find.text('Current page'), findsOneWidget);
    expect(find.text('Daily memorization'), findsOneWidget);
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
}
