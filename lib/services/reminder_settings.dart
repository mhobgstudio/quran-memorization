import 'package:shared_preferences/shared_preferences.dart';

/// The user's daily memorization reminder: which mushaf page to open when the
/// reminder fires, at what time of day, and whether it is currently scheduled.
///
/// Persisted in [SharedPreferences] under `reminder.*` keys, following the
/// same load/save pattern as [PlannerSettings] and [MemorizationLog].
class ReminderSettings {
  const ReminderSettings({
    this.enabled = false,
    this.page = 1,
    this.hour = 20,
    this.minute = 0,
  });

  /// Whether a daily reminder is currently scheduled.
  final bool enabled;

  /// Page (1..604) the reminder deep-links to when tapped.
  final int page;

  /// Hour of day (0..23) the daily reminder fires.
  final int hour;

  /// Minute of the hour (0..59) the daily reminder fires.
  final int minute;

  static const _kEnabled = 'reminder.enabled';
  static const _kPage = 'reminder.page';
  static const _kHour = 'reminder.hour';
  static const _kMinute = 'reminder.minute';

  ReminderSettings copyWith({
    bool? enabled,
    int? page,
    int? hour,
    int? minute,
  }) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      page: page ?? this.page,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  /// Loads persisted settings, falling back to defaults (off, 20:00, page 1)
  /// when a key is missing or unreadable.
  static Future<ReminderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ReminderSettings(
      enabled: prefs.getBool(_kEnabled) ?? false,
      page: (prefs.getInt(_kPage) ?? 1).clamp(1, 604),
      hour: (prefs.getInt(_kHour) ?? 20).clamp(0, 23),
      minute: (prefs.getInt(_kMinute) ?? 0).clamp(0, 59),
    );
  }

  /// Persists these settings for the next app launch.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
    await prefs.setInt(_kPage, page);
    await prefs.setInt(_kHour, hour);
    await prefs.setInt(_kMinute, minute);
  }
}
