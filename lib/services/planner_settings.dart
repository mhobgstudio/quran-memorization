import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../memorization_calc.dart' show MemorizationDirection;

/// Persisted planner inputs so the user's memorization plan (current page,
/// daily rate, direction, rest days, start date) and the app theme survive
/// app restarts.
///
/// Values are stored in [SharedPreferences] under `plan.*` (and `theme.*`)
/// keys and applied as the initial state when the planner screen opens.
class PlannerSettings {
  const PlannerSettings({
    this.page = 1,
    this.rate = 10,
    this.rateIsLines = true,
    this.direction = MemorizationDirection.forward,
    this.restWeekdays = const {},
    this.startDate,
    this.themeMode = ThemeMode.system,
  });

  /// Current page being memorized (1-604).
  final int page;

  /// Daily rate: lines per day when [rateIsLines], else fraction of a page.
  final double rate;

  /// Whether [rate] means lines-per-day (true) or pages-per-day (false).
  final bool rateIsLines;

  /// Whether memorization runs page 1 → 604 or 604 → 1.
  final MemorizationDirection direction;

  /// Weekdays (DateTime.weekday: 1=Mon .. 7=Sun) the user rests.
  final Set<int> restWeekdays;

  /// When the plan starts (date only); null means today.
  final DateTime? startDate;

  /// App color theme; defaults to following the system.
  final ThemeMode themeMode;

  static const _kPage = 'plan.page';
  static const _kRate = 'plan.rate';
  static const _kRateLines = 'plan.rateIsLines';
  static const _kDirection = 'plan.direction';
  static const _kRestDays = 'plan.restWeekdays';
  static const _kStartDate = 'plan.startDate';
  static const _kTheme = 'theme.mode';

  PlannerSettings copyWith({
    int? page,
    double? rate,
    bool? rateIsLines,
    MemorizationDirection? direction,
    Set<int>? restWeekdays,
    DateTime? startDate,
    bool clearStartDate = false,
    ThemeMode? themeMode,
  }) {
    return PlannerSettings(
      page: page ?? this.page,
      rate: rate ?? this.rate,
      rateIsLines: rateIsLines ?? this.rateIsLines,
      direction: direction ?? this.direction,
      restWeekdays: restWeekdays ?? this.restWeekdays,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      themeMode: themeMode ?? this.themeMode,
    );
  }

  /// Loads persisted settings, falling back to defaults when a key is
  /// missing or unreadable.
  static Future<PlannerSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PlannerSettings(
      page: (prefs.getInt(_kPage) ?? 1).clamp(1, 604),
      rate: prefs.getDouble(_kRate) ?? 10,
      rateIsLines: prefs.getBool(_kRateLines) ?? true,
      direction: MemorizationDirection.values.firstWhere(
        (d) => d.name == prefs.getString(_kDirection),
        orElse: () => MemorizationDirection.forward,
      ),
      restWeekdays: (prefs.getStringList(_kRestDays) ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .where((w) => w >= 1 && w <= 7)
          .toSet(),
      startDate: _parseDate(prefs.getString(_kStartDate)),
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == prefs.getString(_kTheme),
        orElse: () => ThemeMode.system,
      ),
    );
  }

  /// Persists these settings for the next app launch.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPage, page);
    await prefs.setDouble(_kRate, rate);
    await prefs.setBool(_kRateLines, rateIsLines);
    await prefs.setString(_kDirection, direction.name);
    await prefs.setStringList(
      _kRestDays,
      restWeekdays.map((w) => '$w').toList()..sort(),
    );
    final start = startDate;
    if (start == null) {
      await prefs.remove(_kStartDate);
    } else {
      await prefs.setString(
        _kStartDate,
        '${start.year.toString().padLeft(4, '0')}-'
            '${start.month.toString().padLeft(2, '0')}-'
            '${start.day.toString().padLeft(2, '0')}',
      );
    }
    await prefs.setString(_kTheme, themeMode.name);
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
}
