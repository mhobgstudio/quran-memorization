import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/services/reminder_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReminderSettings', () {
    test('defaults to disabled, 20:00, page 1', () {
      const s = ReminderSettings();
      expect(s.enabled, isFalse);
      expect(s.page, 1);
      expect(s.hour, 20);
      expect(s.minute, 0);
    });

    test('copyWith replaces only the given fields', () {
      const base = ReminderSettings();
      final updated = base.copyWith(enabled: true, page: 37, minute: 30);
      expect(updated.enabled, isTrue);
      expect(updated.page, 37);
      expect(updated.minute, 30);
      expect(updated.hour, base.hour);
    });

    test('round-trips through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      const saved = ReminderSettings(
        enabled: true,
        page: 42,
        hour: 6,
        minute: 15,
      );
      await saved.save();
      final loaded = await ReminderSettings.load();
      expect(loaded.enabled, saved.enabled);
      expect(loaded.page, saved.page);
      expect(loaded.hour, saved.hour);
      expect(loaded.minute, saved.minute);
    });

    test('falls back to defaults when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final loaded = await ReminderSettings.load();
      expect(loaded.enabled, isFalse);
      expect(loaded.page, 1);
      expect(loaded.hour, 20);
    });

    test('clamps out-of-range values on load', () async {
      SharedPreferences.setMockInitialValues({
        'reminder.page': 999,
        'reminder.hour': 25,
        'reminder.minute': -5,
      });
      final loaded = await ReminderSettings.load();
      expect(loaded.page, 604);
      expect(loaded.hour, 23);
      expect(loaded.minute, 0);
    });
  });
}
