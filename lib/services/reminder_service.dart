import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'dart:async' show unawaited;

import '../data/encouraging_verses.dart';

/// The surface of `FlutterLocalNotificationsPlugin` that [ReminderService]
/// uses — an interface so tests can substitute a recording fake without
/// touching platform channels.
abstract class ReminderNotifier {
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  });

  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  });

  Future<void> cancel({required int id, String? tag});

  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails();
}

/// Real [ReminderNotifier] backed by the plugin's singleton.
class PluginNotifier implements ReminderNotifier {
  PluginNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async {
    final ok = await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );
    // Android 13+ requires a runtime notification permission.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    return ok;
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
  }) {
    return _plugin.zonedSchedule(
      id: id,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: androidScheduleMode,
      title: title,
      body: body,
      payload: payload,
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  @override
  Future<void> cancel({required int id, String? tag}) =>
      _plugin.cancel(id: id, tag: tag);

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() =>
      _plugin.getNotificationAppLaunchDetails();
}

/// Schedules the app's single daily "time to memorize" system notification
/// and routes notification taps back into the app.
///
/// Uses local scheduled notifications (`flutter_local_notifications`) rather
/// than a remote push service: the app is offline-first, so FCM would add a
/// backend for no benefit. The notification repeats daily via
/// `matchDateTimeComponents: DateTimeComponents.time` and carries the target
/// page in its payload, so tapping it deep-links straight to that page of the
/// mushaf (warm launch or cold start).
///
/// Scheduling uses `AndroidScheduleMode.inexactAllowWhileIdle`: exact
/// delivery is not needed for a daily study reminder, and this avoids the
/// `SCHEDULE_EXACT_ALARM` permission dialog on Android 12+ (the system may
/// delay the alert slightly while the device is dozing).
class ReminderService {
  ReminderService({ReminderNotifier? notifier})
    : _notifier = notifier ?? PluginNotifier();

  final ReminderNotifier _notifier;

  /// Notification id of the daily reminder (a single repeating slot).
  static const int _reminderId = 1;

  /// Fallback instance for screens built without an injected service (tests,
  /// previews). It is never initialized, so its scheduling calls fail
  /// gracefully instead of crashing.
  static final ReminderService shared = ReminderService();

  /// Called when the user taps the reminder notification, with the target
  /// page (1..604). Wired up by the app shell in `main()`.
  void Function(int page)? onTap;

  bool _initialized = false;
  bool _tzReady = false;

  /// Loads the timezone database (synchronous). Safe to call repeatedly.
  void _loadTimezoneDatabase() {
    if (_tzReady) return;
    _tzReady = true;
    tz_data.initializeTimeZones();
  }

  /// Best-effort lookup of the device timezone; never throws. On unsupported
  /// platforms or in widget tests (fake async zone) it fails or never
  /// completes, and scheduling falls back to UTC wall-clock.
  Future<void> _applyDeviceTimezone() async {
    if (kIsWeb) return;
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Unknown timezone: keep UTC.
    }
  }

  /// The device timezone, falling back to UTC when the database hasn't been
  /// loaded (so scheduling never crashes even without [initialize]).
  tz.Location get _location {
    try {
      return tz.local;
    } catch (_) {
      return tz.UTC;
    }
  }

  /// Initializes the plugin (once): timezone database, per-platform settings,
  /// notification permissions, and the tap callback. Returns the target page
  /// when this app launch was triggered by tapping the reminder (cold start),
  /// or null otherwise.
  ///
  /// Safe to call multiple times; only the first call does work.
  Future<int?> initialize() async {
    if (_initialized) return _launchPage();
    _initialized = true;

    // Scheduled notifications are a platform feature; the web build has no
    // background scheduler, so it degrades to a no-op.
    if (kIsWeb) return null;

    _loadTimezoneDatabase();
    // Await the device-timezone lookup here (app startup): it resolves in
    // milliseconds on a real device, and scheduling afterwards uses the
    // correct local time instead of racing the lookup.
    await _applyDeviceTimezone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Darwin asks for permissions at init (the defaults request all three).
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
    );
    const linux = LinuxInitializationSettings(defaultActionName: 'Open');
    const windows = WindowsInitializationSettings(
      appName: 'Hifz Planner',
      appUserModelId: 'dev.heavenly.hifzplanner',
      guid: '{6f2a9c1e-8b3d-4a5e-9c77-2e0d41b8f5a1}',
    );

    await _notifier.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
        linux: linux,
        windows: windows,
      ),
      onDidReceiveNotificationResponse: _onResponse,
    );

    return _launchPage();
  }

  /// Schedules (or reschedules) the daily reminder for [hour]:[minute],
  /// targeting [page]. Returns false when the platform can't schedule (web)
  /// or the platform channel is unavailable (e.g. widget tests).
  Future<bool> schedule({
    required int page,
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return false;
    _loadTimezoneDatabase();
    // When [initialize] already ran the device-timezone lookup, await it
    // to guarantee the correct local time. In widget tests ([initialize]
    // was never called) the platform channel never resolves, so we fire
    // and forget to avoid hanging the test.
    if (_initialized) {
      await _applyDeviceTimezone();
    } else {
      unawaited(_applyDeviceTimezone());
    }
    final verse = encouragingVerseFor(DateTime.now());
    final scheduled = _nextDaily(hour, minute);
    try {
      await _notifier.zonedSchedule(
        id: _reminderId,
        title: 'Hifz reminder · page $page',
        body: '${verse.arabic} — ${verse.translation} (${verse.reference})',
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            'Daily memorization reminder',
            channelDescription: 'Reminds you to review today\'s portion.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
          linux: LinuxNotificationDetails(),
          windows: WindowsNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '$page',
      );
      return true;
    } catch (e) {
      debugPrint('ReminderService.schedule failed: $e');
      return false;
    }
  }

  /// Cancels the daily reminder, if scheduled.
  Future<void> cancel() async {
    if (kIsWeb) return;
    try {
      await _notifier.cancel(id: _reminderId);
    } catch (_) {
      // Nothing to cancel (uninitialized platform, widget test, ...).
    }
  }

  /// The next occurrence of [hour]:[minute] in the device's local timezone,
  /// skipping to tomorrow when today's time has already passed.
  tz.TZDateTime _nextDaily(int hour, int minute) {
    final location = _location;
    final now = tz.TZDateTime.now(location);
    var scheduled = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// The page a notification tap deep-links to, parsed from its payload.
  /// Returns null for missing, non-numeric or out-of-range payloads so a
  /// corrupted notification never navigates to an arbitrary page.
  static int? _pageFromPayload(String? payload) {
    final value = int.tryParse(payload ?? '');
    if (value == null || value < 1 || value > 604) return null;
    return value;
  }

  Future<int?> _launchPage() async {
    final details = await _notifier.getNotificationAppLaunchDetails();
    return _pageFromPayload(details?.notificationResponse?.payload);
  }

  void _onResponse(NotificationResponse response) {
    final page = _pageFromPayload(response.payload);
    if (page != null) onTap?.call(page);
  }
}
