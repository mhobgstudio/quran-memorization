import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/memorization_calc.dart';

void main() {
  group('MemorizationPlan validation', () {
    test('rejects current page below 1', () {
      expect(
        () => MemorizationPlan(currentPage: 0, pagesPerDay: 1),
        throwsArgumentError,
      );
    });

    test('rejects current page above 604', () {
      expect(
        () => MemorizationPlan(currentPage: 605, pagesPerDay: 1),
        throwsArgumentError,
      );
    });

    test('rejects non-positive pages per day', () {
      expect(
        () => MemorizationPlan(currentPage: 1, pagesPerDay: 0),
        throwsArgumentError,
      );
      expect(
        () => MemorizationPlan(currentPage: 1, pagesPerDay: -2),
        throwsArgumentError,
      );
    });

    test('rejects invalid rest weekday values', () {
      expect(
        () => MemorizationPlan(
          currentPage: 1,
          pagesPerDay: 1,
          restWeekdays: const {8},
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid lines per day', () {
      expect(
        () => MemorizationPlan.fromLinesPerDay(
          currentPage: 1,
          linesPerDay: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('remaining pages', () {
    test('page 1 means all 604 pages remain', () {
      final plan = MemorizationPlan(currentPage: 1, pagesPerDay: 1);
      expect(plan.remainingPages, 604);
    });

    test('page 604 means 1 page remains (current page counted)', () {
      final plan = MemorizationPlan(currentPage: 604, pagesPerDay: 1);
      expect(plan.remainingPages, 1);
    });

    test('page 300 means 305 pages remain', () {
      final plan = MemorizationPlan(currentPage: 300, pagesPerDay: 1);
      expect(plan.remainingPages, 305);
    });
  });

  group('compute() without rest days', () {
    test('one page per day from page 1 finishes in 604 study days', () {
      final plan = MemorizationPlan(
        currentPage: 1,
        pagesPerDay: 1,
        startDate: DateTime(2026, 8, 10), // Monday
      );
      final result = plan.compute();
      expect(result.studyDays, 604);
      expect(result.calendarDays, 604);
      // 2026-08-10 + 603 days = 2028-04-04
      expect(result.finishDate, DateTime(2028, 4, 4));
    });

    test('half page per day from page 1 needs 1208 study days', () {
      final plan = MemorizationPlan(
        currentPage: 1,
        pagesPerDay: 0.5,
        startDate: DateTime(2026, 8, 10),
      );
      final result = plan.compute();
      expect(result.studyDays, 1208);
    });

    test('fractional pages per day (1/3 page) rounds up study days', () {
      // 604 / (1/3) = 1812 exactly.
      final plan = MemorizationPlan(
        currentPage: 1,
        pagesPerDay: 1 / 3,
        startDate: DateTime(2026, 8, 10),
      );
      expect(plan.compute().studyDays, 1812);
    });

    test('starting at page 604 with 1 page/day finishes today', () {
      final plan = MemorizationPlan(
        currentPage: 604,
        pagesPerDay: 1,
        startDate: DateTime(2026, 8, 10),
      );
      final result = plan.compute();
      expect(result.studyDays, 1);
      expect(result.calendarDays, 1);
      expect(result.finishDate, DateTime(2026, 8, 10));
    });
  });

  group('compute() with rest days', () {
    test('6 days/week skipping Sunday: 604 study days = 704 calendar days', () {
      final plan = MemorizationPlan(
        currentPage: 1,
        pagesPerDay: 1,
        restWeekdays: const {DateTime.sunday},
        startDate: DateTime(2026, 8, 10), // Monday
      );
      final result = plan.compute();
      expect(result.studyDays, 604);
      expect(result.calendarDays, 704);
      // Finish lands on a Thursday (a study day), 2028-07-13.
      expect(result.finishDate, DateTime(2028, 7, 13));
      expect(result.finishDate.weekday, DateTime.thursday);
    });

    test('resting only Sundays never finishes on a Sunday', () {
      final plan = MemorizationPlan(
        currentPage: 1,
        pagesPerDay: 0.37,
        restWeekdays: const {DateTime.sunday},
        startDate: DateTime(2026, 8, 10),
      );
      expect(plan.compute().finishDate.weekday, isNot(DateTime.sunday));
    });

    test('resting every day never completes and returns the cap', () {
      final plan = MemorizationPlan(
        currentPage: 1,
        pagesPerDay: 1,
        restWeekdays: const {1, 2, 3, 4, 5, 6, 7},
        startDate: DateTime(2026, 8, 10),
      );
      final result = plan.compute();
      expect(result.studyDays, 0);
      expect(result.calendarDays, 3_650_000);
    });
  });

  group('lines per day', () {
    test('15 lines/day equals 1 page/day', () {
      final byLines = MemorizationPlan.fromLinesPerDay(
        currentPage: 1,
        linesPerDay: 15,
        startDate: DateTime(2026, 8, 10),
      );
      final byPages = MemorizationPlan(
        currentPage: 1,
        pagesPerDay: 1,
        startDate: DateTime(2026, 8, 10),
      );
      expect(byLines.pagesPerDay, byPages.pagesPerDay);
      expect(byLines.compute().studyDays, byPages.compute().studyDays);
    });

    test('10 lines/day from page 1 needs 906 study days', () {
      final plan = MemorizationPlan.fromLinesPerDay(
        currentPage: 1,
        linesPerDay: 10,
        startDate: DateTime(2026, 8, 10),
      );
      expect(plan.pagesPerDay, closeTo(10 / 15, 1e-9));
      expect(plan.compute().studyDays, 906); // ceil(604 * 15 / 10)
    });
  });

  group('formatting helpers', () {
    test('formatDate renders weekday, month, day, year', () {
      expect(formatDate(DateTime(2026, 8, 11)), 'Tuesday, August 11, 2026');
    });

    test('humanizeDays covers the common cases', () {
      expect(humanizeDays(0), 'today');
      expect(humanizeDays(1), 'tomorrow');
      expect(humanizeDays(42), 'in 42 days');
      expect(humanizeDays(90), 'in 3 months');
      expect(humanizeDays(730), 'in 2 years');
      expect(humanizeDays(790), 'in 2 years 2 months');
    });
  });
}
