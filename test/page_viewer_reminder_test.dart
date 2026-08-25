import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/data/encouraging_verses.dart';
import 'package:quran_memorization/screens/page_viewer_screen.dart';
import 'package:quran_memorization/services/reminder_service.dart';
import 'package:quran_memorization/services/reminder_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'page_viewer_test.dart' show FakeQuranAudio, fixtureMushaf;
import 'reminder_service_test.dart' show FakePlugin;

Widget harness(int page, ReminderService reminder) {
  return MaterialApp(
    home: PageViewerScreen(
      page: page,
      linesPerDay: 1,
      mushaf: fixtureMushaf(),
      audio: FakeQuranAudio(),
      reminder: reminder,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('alarm button opens the reminder sheet with verse preview', (
    tester,
  ) async {
    final plugin = FakePlugin();
    final service = ReminderService(notifier: plugin);
    await tester.pumpWidget(harness(1, service));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.alarm_add_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Daily reminder'), findsOneWidget);
    expect(find.textContaining('page 1'), findsWidgets);
    expect(
      find.textContaining('The notification shows an encouraging verse'),
      findsOneWidget,
    );
    // The sheet previews today's verse (Arabic + translation + reference).
    final verse = encouragingVerseFor(DateTime.now());
    expect(find.text(verse.arabic), findsOneWidget);
    expect(find.textContaining(verse.reference), findsOneWidget);
  });

  testWidgets('saving schedules the notification and persists the config', (
    tester,
  ) async {
    final plugin = FakePlugin();
    final service = ReminderService(notifier: plugin);
    await tester.pumpWidget(harness(1, service));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.alarm_add_outlined));
    await tester.pumpAndSettle();

    // Defaults to 20:00; enable the reminder and save it.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save reminder'));
    await tester.pumpAndSettle();

    expect(plugin.scheduled, hasLength(1));
    final s = plugin.scheduled.single;
    expect(s.id, 1);
    expect(s.payload, '1');
    expect(s.scheduledDate.hour, 20);
    expect(s.scheduledDate.minute, 0);

    final saved = await ReminderSettings.load();
    expect(saved.enabled, isTrue);
    expect(saved.page, 1);

    // The alarm icon flips to the active state.
    expect(find.byIcon(Icons.alarm_on), findsOneWidget);
  });

  testWidgets('disabling saves cancels the scheduled notification', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'reminder.enabled': true,
      'reminder.page': 1,
      'reminder.hour': 20,
      'reminder.minute': 0,
    });
    final plugin = FakePlugin();
    final service = ReminderService(notifier: plugin);
    await tester.pumpWidget(harness(1, service));
    await tester.pumpAndSettle();

    // The active reminder shows the filled alarm icon on this page.
    expect(find.byIcon(Icons.alarm_on), findsOneWidget);

    await tester.tap(find.byIcon(Icons.alarm_on));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch)); // turn it off
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Turn off'));
    await tester.pumpAndSettle();

    expect(plugin.cancelled, isTrue);
    expect(plugin.scheduled, isEmpty);
    final saved = await ReminderSettings.load();
    expect(saved.enabled, isFalse);
    expect(find.byIcon(Icons.alarm_add_outlined), findsOneWidget);
  });

  testWidgets('an existing reminder for another page still shows the active icon', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'reminder.enabled': true,
      'reminder.page': 2,
      'reminder.hour': 7,
      'reminder.minute': 45,
    });
    final service = ReminderService(notifier: FakePlugin());
    await tester.pumpWidget(harness(1, service));
    await tester.pumpAndSettle();

    // The alarm icon is active whenever ANY reminder is enabled, even when
    // the viewer is on a different page.
    expect(find.byIcon(Icons.alarm_on), findsOneWidget);
    // Tooltip still mentions the reminder's actual target page.
    expect(find.byTooltip('Daily reminder · page 2 at 07:45'), findsOneWidget);
  });
}
