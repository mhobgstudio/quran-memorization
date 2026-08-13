import 'package:shared_preferences/shared_preferences.dart';

import '../memorization_calc.dart' show MemorizationDirection;

/// One recorded memorization session (a day's completed portion).
class MemorizationSession {
  const MemorizationSession({
    required this.date,
    required this.page,
    required this.lines,
    required this.direction,
  });

  /// The date (time-of-day discarded) this portion was memorized.
  final DateTime date;

  /// The page memorized that day.
  final int page;

  /// Lines of that page memorized that day (fractions allowed).
  final double lines;

  /// Which end of the mushaf the user memorized toward.
  final MemorizationDirection direction;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Serializes one entry, e.g. "2026-08-13|22|7.5|forward".
  String encode() {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d|$page|$lines|${direction.name}';
  }

  static MemorizationSession? decode(String raw) {
    final parts = raw.split('|');
    if (parts.length != 4) return null;
    final dateParts = parts[0].split('-');
    if (dateParts.length != 3) return null;
    final y = int.tryParse(dateParts[0]);
    final m = int.tryParse(dateParts[1]);
    final d = int.tryParse(dateParts[2]);
    final page = int.tryParse(parts[1]);
    final lines = double.tryParse(parts[2]);
    final direction = MemorizationDirection.values.firstWhere(
      (dir) => dir.name == parts[3],
      orElse: () => MemorizationDirection.forward,
    );
    if (y == null || m == null || d == null || page == null || lines == null) {
      return null;
    }
    return MemorizationSession(
      date: DateTime(y, m, d),
      page: page,
      lines: lines,
      direction: direction,
    );
  }
}

/// Local record of the user's completed memorization days, used for the
/// \"mark today's portion done\" button, the current streak, and the
/// history shown on the planner screen.
///
/// Persisted in [SharedPreferences] under the `log.*` keys as a compact
/// newline-separated list of sessions.
class MemorizationLog {
  const MemorizationLog({this.sessions = const []});

  /// Sessions, newest-first (callers must pass them already sorted).
  final List<MemorizationSession> sessions;

  static const _kSessions = 'log.sessions';

  static List<MemorizationSession> _sorted(
    Iterable<MemorizationSession> input,
  ) {
    final list = input.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Sessions, newest-first; never mutated by callers.
  List<MemorizationSession> get allSessions => List.unmodifiable(sessions);

  int get totalSessions => sessions.length;

  /// Total lines memorized across all sessions.
  double get totalLines => sessions.fold(0, (sum, s) => sum + s.lines);

  /// The most recent session, if any.
  MemorizationSession? get latest => sessions.isEmpty ? null : sessions.first;

  /// Whether a session was recorded on [date] (default today).
  bool isDoneOn(DateTime date) {
    final target = MemorizationSession._dateOnly(date);
    return sessions.any((s) => s.date == target);
  }

  /// Consecutive days with a recorded session, counting back from today
  /// (or from yesterday when today isn't done yet, so the streak doesn't
  /// die at midnight before the day's session).
  int get streak {
    var day = DateTime.now();
    day = DateTime(day.year, day.month, day.day);
    if (!isDoneOn(day)) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    var count = 0;
    while (sessions.any((s) => s.date == day)) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  /// Records (or replaces) the session for [date], returning a new log.
  MemorizationLog record({
    required DateTime date,
    required int page,
    required double lines,
    required MemorizationDirection direction,
  }) {
    final day = MemorizationSession._dateOnly(date);
    final rest = sessions.where((s) => s.date != day).toList();
    rest.add(
      MemorizationSession(
        date: day,
        page: page,
        lines: lines,
        direction: direction,
      ),
    );
    return MemorizationLog(sessions: _sorted(rest));
  }

  /// Removes the session recorded on [date], returning a new log.
  MemorizationLog remove(DateTime date) {
    final day = MemorizationSession._dateOnly(date);
    return MemorizationLog(
      sessions: _sorted(sessions.where((s) => s.date != day)),
    );
  }

  /// Loads the persisted log, ignoring unreadable entries.
  static Future<MemorizationLog> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kSessions) ?? const [];
    final sessions = raw
        .map(MemorizationSession.decode)
        .whereType<MemorizationSession>()
        .toList();
    return MemorizationLog(sessions: _sorted(sessions));
  }

  /// Persists this log for the next app launch.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kSessions,
      sessions.map((s) => s.encode()).toList(),
    );
  }
}
