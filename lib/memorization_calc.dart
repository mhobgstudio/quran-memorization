import 'package:flutter/foundation.dart';

/// Result of running a [MemorizationPlan] to completion.
@immutable
class PlanResult {
  const PlanResult({
    required this.studyDays,
    required this.calendarDays,
    required this.finishDate,
  });

  /// Number of memorization sessions required (excludes rest days).
  final int studyDays;

  /// Number of calendar days from [MemorizationPlan.startDate] until
  /// [finishDate], inclusive of the finish day.
  final int calendarDays;

  /// The exact date on which the final memorization session happens.
  final DateTime finishDate;
}

/// Pure calculation logic for a Quran memorization plan.
///
/// Uses the standard Madani mushaf: 604 pages, 15 lines per page.
@immutable
class MemorizationPlan {
  MemorizationPlan({
    required int currentPage,
    required double pagesPerDay,
    Set<int> restWeekdays = const {},
    DateTime? startDate,
  })  : currentPage = currentPage,
        pagesPerDay = pagesPerDay,
        restWeekdays = Set.unmodifiable(restWeekdays),
        startDate = startDate ?? _todayDate() {
    if (currentPage < 1 || currentPage > totalPages) {
      throw ArgumentError.value(
        currentPage,
        'currentPage',
        'must be between 1 and $totalPages',
      );
    }
    if (pagesPerDay <= 0 || !pagesPerDay.isFinite) {
      throw ArgumentError.value(
        pagesPerDay,
        'pagesPerDay',
        'must be a positive finite number',
      );
    }
    if (!restWeekdays.every((w) => w >= 1 && w <= 7)) {
      throw ArgumentError.value(
        restWeekdays,
        'restWeekdays',
        'weekday values must be in 1..7 (Monday..Sunday)',
      );
    }
  }

  /// Builds a plan from lines memorized per day instead of pages per day.
  factory MemorizationPlan.fromLinesPerDay({
    required int currentPage,
    required double linesPerDay,
    Set<int> restWeekdays = const {},
    DateTime? startDate,
  }) {
    if (linesPerDay <= 0 || !linesPerDay.isFinite) {
      throw ArgumentError.value(
        linesPerDay,
        'linesPerDay',
        'must be a positive finite number',
      );
    }
    return MemorizationPlan(
      currentPage: currentPage,
      pagesPerDay: linesPerDay / linesPerPage,
      restWeekdays: restWeekdays,
      startDate: startDate,
    );
  }

  /// Total pages in the standard Madani mushaf.
  static const int totalPages = 604;

  /// Lines per page in the standard Madani mushaf.
  static const int linesPerPage = 15;

  /// The page currently being memorized (1-based). Counted as in progress,
  /// so the remaining work includes it.
  final int currentPage;

  /// Pages memorized per study day (fractions allowed).
  final double pagesPerDay;

  /// Weekdays on which the user does NOT memorize.
  /// Uses [DateTime.weekday] convention: 1 = Monday ... 7 = Sunday.
  final Set<int> restWeekdays;

  /// The date memorization starts (inclusive). Defaults to today.
  final DateTime startDate;

  static DateTime _todayDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Pages still to memorize, counting [currentPage] as incomplete.
  double get remainingPages => (totalPages - currentPage + 1).toDouble();

  /// Pages fully memorized before [currentPage] (for progress display).
  double get completedPages => (currentPage - 1).toDouble();

  /// Fraction of the whole mushaf completed before [currentPage].
  double get progressBeforeCurrentPage => completedPages / totalPages;

  /// Walks the calendar day by day from [startDate], consuming
  /// [pagesPerDay] of remaining work on each non-rest weekday, until the
  /// memorization is complete. Returns the [PlanResult] with the exact
  /// finish date, study-day count, and calendar-day count.
  PlanResult compute() {
    double remaining = remainingPages;
    var day = DateTime(startDate.year, startDate.month, startDate.day);
    var finish = day;
    var studyDays = 0;
    // Absorbs floating-point residue from iterative subtraction (e.g.
    // 604 - 1812 * (1/3) leaves ~1e-13).
    const double epsilon = 1e-9;
    // Safety cap ~10,000 years of calendar days; unreachable for sane input.
    const int maxCalendarDays = 3_650_000;
    for (var calendar = 1; calendar <= maxCalendarDays; calendar++) {
      if (!restWeekdays.contains(day.weekday)) {
        remaining -= pagesPerDay;
        studyDays++;
        if (remaining <= epsilon) {
          finish = day;
          return PlanResult(
            studyDays: studyDays,
            calendarDays: calendar,
            finishDate: finish,
          );
        }
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    // Extremely slow plan (e.g. 1 line every 40 years). Return the cap
    // rather than hanging.
    return PlanResult(
      studyDays: studyDays,
      calendarDays: maxCalendarDays,
      finishDate: day,
    );
  }
}

/// Formats [date] as e.g. "Tuesday, August 11, 2026" without external deps.
String formatDate(DateTime date) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  const weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday',
  ];
  return '${weekdays[date.weekday - 1]}, '
      '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// Humanizes a number of calendar days into a short phrase:
/// "today", "tomorrow", "in 42 days", "in 3 months", "in 2 years 2 months".
String humanizeDays(int days) {
  if (days <= 0) return 'today';
  if (days == 1) return 'tomorrow';
  // Under two months, raw days read better than "1 month".
  if (days < 60) return 'in $days day${days == 1 ? '' : 's'}';
  final years = days ~/ 365;
  final months = (days % 365) ~/ 30;
  if (years > 0 && months > 0) {
    return 'in $years year${years == 1 ? '' : 's'} $months month${months == 1 ? '' : 's'}';
  }
  if (years > 0) return 'in $years year${years == 1 ? '' : 's'}';
  return 'in $months month${months == 1 ? '' : 's'}';
}
