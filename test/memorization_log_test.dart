import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/memorization_calc.dart';
import 'package:quran_memorization/services/memorization_log.dart';
import 'package:quran_memorization/services/planner_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MemorizationLog', () {
    test('starts empty with zero streak', () {
      final log = MemorizationLog();
      expect(log.totalSessions, 0);
      expect(log.streak, 0);
      expect(log.latest, isNull);
    });

    test('record adds a session and replaces same-day entries', () {
      final today = DateTime.now();
      var log = MemorizationLog();
      log = log.record(
        date: today,
        page: 22,
        lines: 7.5,
        direction: MemorizationDirection.forward,
      );
      expect(log.totalSessions, 1);
      expect(log.latest!.page, 22);
      expect(log.latest!.lines, 7.5);

      // Recording again the same day replaces, not duplicates.
      log = log.record(
        date: today,
        page: 23,
        lines: 5,
        direction: MemorizationDirection.forward,
      );
      expect(log.totalSessions, 1);
      expect(log.latest!.page, 23);
    });

    test('remove deletes a specific day', () {
      final today = DateTime.now();
      final yesterday = DateTime(
        today.year,
        today.month,
        today.day - 1,
      );
      var log = MemorizationLog();
      log = log.record(
        date: yesterday,
        page: 1,
        lines: 10,
        direction: MemorizationDirection.forward,
      );
      log = log.record(
        date: today,
        page: 1,
        lines: 10,
        direction: MemorizationDirection.forward,
      );
      expect(log.totalSessions, 2);
      log = log.remove(today);
      expect(log.totalSessions, 1);
      expect(log.latest!.date, yesterday);
    });

    test('streak counts consecutive days ending today', () {
      final today = DateTime.now();
      var log = MemorizationLog();
      for (var i = 0; i < 4; i++) {
        log = log.record(
          date: DateTime(today.year, today.month, today.day - i),
          page: 1,
          lines: 10,
          direction: MemorizationDirection.forward,
        );
      }
      expect(log.streak, 4);
      // A gap breaks the streak.
      log = log.record(
        date: DateTime(today.year, today.month, today.day - 6),
        page: 1,
        lines: 10,
        direction: MemorizationDirection.forward,
      );
      expect(log.streak, 4);
    });

    test('streak survives a not-yet-done today (counts from yesterday)', () {
      final today = DateTime.now();
      var log = MemorizationLog();
      // Done yesterday and the day before, but not today yet.
      for (var i = 1; i <= 3; i++) {
        log = log.record(
          date: DateTime(today.year, today.month, today.day - i),
          page: 1,
          lines: 10,
          direction: MemorizationDirection.forward,
        );
      }
      expect(log.streak, 3);
    });

    test('session encode/decode round-trips', () {
      final real = MemorizationSession(
        date: DateTime(2026, 8, 13),
        page: 22,
        lines: 7.5,
        direction: MemorizationDirection.backward,
      );
      final decoded = MemorizationSession.decode(real.encode());
      expect(decoded, isNotNull);
      expect(decoded!.date, DateTime(2026, 8, 13));
      expect(decoded.page, 22);
      expect(decoded.lines, 7.5);
      expect(decoded.direction, MemorizationDirection.backward);
    });

    test('load/save round-trips through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final today = DateTime.now();
      var log = MemorizationLog();
      log = log.record(
        date: today,
        page: 42,
        lines: 5,
        direction: MemorizationDirection.backward,
      );
      await log.save();

      final loaded = await MemorizationLog.load();
      expect(loaded.totalSessions, 1);
      expect(loaded.latest!.page, 42);
      expect(loaded.latest!.direction, MemorizationDirection.backward);
    });
  });

  group('PlannerSettings', () {
    test('load/save round-trips through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      const settings = PlannerSettings(
        page: 22,
        rate: 7.5,
        rateIsLines: false,
        direction: MemorizationDirection.backward,
        restWeekdays: {1, 5},
        startDate: null,
        themeMode: ThemeMode.dark,
      );
      await settings.save();

      final loaded = await PlannerSettings.load();
      expect(loaded.page, 22);
      expect(loaded.rate, 7.5);
      expect(loaded.rateIsLines, false);
      expect(loaded.direction, MemorizationDirection.backward);
      expect(loaded.restWeekdays, {1, 5});
      expect(loaded.themeMode, ThemeMode.dark);
    });

    test('copyWith clears the start date when requested', () {
      const settings = PlannerSettings(startDate: null);
      final withDate = settings.copyWith(startDate: DateTime(2026, 9, 1));
      expect(withDate.startDate, DateTime(2026, 9, 1));
      final cleared = withDate.copyWith(clearStartDate: true);
      expect(cleared.startDate, isNull);
    });
  });
}
