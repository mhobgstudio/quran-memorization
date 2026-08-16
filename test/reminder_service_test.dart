import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/data/encouraging_verses.dart';
import 'package:quran_memorization/services/reminder_service.dart';
import 'package:timezone/timezone.dart' as tz;

/// Records what the real plugin would send, instead of touching platform
/// channels (which throw MissingPluginException in tests).
class FakePlugin implements ReminderNotifier {
  InitializationSettings? initSettings;
  DidReceiveNotificationResponseCallback? onResponse;
  final scheduled =
      <
        ({
          int id,
          String? title,
          String? body,
          tz.TZDateTime scheduledDate,
          String? payload,
          DateTimeComponents? matchDateTimeComponents,
        })
      >[];
  bool cancelled = false;
  bool failSchedule = false;
  NotificationAppLaunchDetails? launchDetails;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async {
    initSettings = settings;
    onResponse = onDidReceiveNotificationResponse;
    return true;
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    if (failSchedule) throw Exception('platform channel unavailable');
    scheduled.add((
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      payload: payload,
      matchDateTimeComponents: matchDateTimeComponents,
    ));
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelled = true;
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => launchDetails;
}

void main() {
  test(
    'initialize wires the tap callback and returns no launch page by default',
    () async {
      final plugin = FakePlugin();
      final service = ReminderService(notifier: plugin);
      final launchPage = await service.initialize();
      expect(launchPage, isNull);
      expect(plugin.initSettings, isNotNull);
      expect(plugin.onResponse, isNotNull);
    },
  );

  test(
    'initialize reports the launch page when the app was opened by a tap',
    () async {
      final plugin = FakePlugin()
        ..launchDetails = const NotificationAppLaunchDetails(
          true,
          notificationResponse: NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: '37',
          ),
        );
      final service = ReminderService(notifier: plugin);
      expect(await service.initialize(), 37);
    },
  );

  test('tapping the notification routes the payload page to onTap', () async {
    final plugin = FakePlugin();
    final service = ReminderService(notifier: plugin);
    await service.initialize();
    final tapped = <int>[];
    service.onTap = tapped.add;

    plugin.onResponse!(
      const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: '123',
      ),
    );
    expect(tapped, [123]);
  });

  test('invalid payloads are ignored', () async {
    final plugin = FakePlugin();
    final service = ReminderService(notifier: plugin);
    await service.initialize();
    final tapped = <int>[];
    service.onTap = tapped.add;

    for (final payload in ['', 'abc', '0', '605', '1.5']) {
      plugin.onResponse!(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: payload,
        ),
      );
    }
    expect(tapped, isEmpty);
  });

  test(
    'schedule books the next daily occurrence with the verse as body',
    () async {
      final plugin = FakePlugin();
      final service = ReminderService(notifier: plugin);
      await service.initialize();

      final ok = await service.schedule(page: 7, hour: 6, minute: 30);
      expect(ok, isTrue);
      expect(plugin.scheduled, hasLength(1));

      final s = plugin.scheduled.single;
      expect(s.id, 1);
      expect(s.payload, '7');
      expect(s.title, contains('page 7'));
      expect(s.matchDateTimeComponents, DateTimeComponents.time);
      expect(s.scheduledDate.hour, 6);
      expect(s.scheduledDate.minute, 30);
      expect(s.scheduledDate.isAfter(tz.TZDateTime.now(tz.local)), isTrue);

      final verse = encouragingVerseFor(DateTime.now());
      expect(s.body, contains(verse.arabic));
      expect(s.body, contains(verse.reference));
    },
  );

  test(
    'schedule fails gracefully when the platform channel is unavailable',
    () async {
      // A platform that throws (widget tests, unsupported platforms) makes
      // schedule return false instead of crashing the UI.
      final plugin = FakePlugin()..failSchedule = true;
      final service = ReminderService(notifier: plugin);
      final ok = await service.schedule(page: 1, hour: 9, minute: 0);
      expect(ok, isFalse);
    },
  );

  test('cancel removes the daily reminder', () async {
    final plugin = FakePlugin();
    final service = ReminderService(notifier: plugin);
    await service.initialize();
    await service.cancel();
    expect(plugin.cancelled, isTrue);
  });
}
