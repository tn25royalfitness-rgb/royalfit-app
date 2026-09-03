import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Decoded tap payload for a reminder notification - which reminder, and
/// what kind, so `main.dart` can route meal/water taps to the food-log
/// screen and everything else to the plain done/not-now screen.
class ReminderTapPayload {
  const ReminderTapPayload({required this.eventId, required this.reminderType});

  final String eventId;
  final String reminderType;

  static ReminderTapPayload? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['event_id'] is String) {
        return ReminderTapPayload(
          eventId: decoded['event_id'] as String,
          reminderType: decoded['reminder_type'] as String? ?? 'custom',
        );
      }
    } catch (_) {
      // Fall through - older/malformed payloads are treated as absent.
    }
    return null;
  }
}

/// Thin wrapper around `flutter_local_notifications`. Two jobs:
///  1. Display incoming FCM messages manually - FCM only auto-displays a
///     system notification for the (unused here) `notification` payload
///     shape, and never for foreground delivery regardless of shape.
///  2. Reminders specifically get `fullScreenIntent: true` - the actual
///     payoff of building a native app instead of staying a PWA. Tapping
///     (or the full-screen takeover itself, on a locked device) fires
///     [onReminderTapped].
class LocalNotifications {
  LocalNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String defaultChannelId = 'royalfitness_default';
  static const String defaultChannelName = 'Royal Fitness Notifications';

  static const String reminderChannelId = 'royalfitness_reminders';
  static const String reminderChannelName = 'Punch-in & Habit Reminders';

  /// Set by `main.dart` - called whenever a reminder notification is tapped
  /// (from foreground, background, or a cold start via [initialize]'s
  /// `didNotificationLaunchApp`).
  static void Function(ReminderTapPayload payload)? onReminderTapped;

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleResponse,
      onDidReceiveBackgroundNotificationResponse: _handleBackgroundResponse,
    );

    const defaultChannel = AndroidNotificationChannel(
      defaultChannelId,
      defaultChannelName,
      description: 'General notifications from Royal Fitness',
      importance: Importance.high,
    );
    const reminderChannel = AndroidNotificationChannel(
      reminderChannelId,
      reminderChannelName,
      description: 'Punch-in and habit reminders',
      importance: Importance.max,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(defaultChannel);
    await androidPlugin?.createNotificationChannel(reminderChannel);

    // Cold start: the app was launched *by* tapping a notification.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final rawPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true && rawPayload != null) {
      final parsed = ReminderTapPayload.tryParse(rawPayload);
      if (parsed != null) onReminderTapped?.call(parsed);
    }
  }

  static void _handleResponse(NotificationResponse response) {
    final rawPayload = response.payload;
    if (rawPayload == null) return;
    final parsed = ReminderTapPayload.tryParse(rawPayload);
    if (parsed != null) onReminderTapped?.call(parsed);
  }

  @pragma('vm:entry-point')
  static void _handleBackgroundResponse(NotificationResponse response) {
    // Runs in a separate background isolate with no app state - the actual
    // navigation happens in the foreground isolate via getNotificationAppLaunchDetails
    // when the app is subsequently brought to the foreground, same as any
    // other cold-start-from-notification flow.
  }

  static Future<void> show({
    required String title,
    String? body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      defaultChannelId,
      defaultChannelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Shows a reminder with Android's full-screen intent - on a locked
  /// device this takes over the screen the way an alarm clock does, rather
  /// than just posting a notification. The tap payload is JSON-encoded
  /// (`{"event_id":..., "reminder_type":...}`) so `main.dart` can route
  /// meal/water taps to the food-log screen and everything else to the
  /// plain reminder-response screen.
  static Future<void> showReminder({
    required String eventId,
    required String reminderType,
    required String title,
    String? body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      reminderChannelId,
      reminderChannelName,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.reminder,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: jsonEncode({'event_id': eventId, 'reminder_type': reminderType}),
    );
  }
}
