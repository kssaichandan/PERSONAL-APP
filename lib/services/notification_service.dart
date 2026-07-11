import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  FlutterLocalNotificationsPlugin get notifications => _notifications;

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(const InitializationSettings(android: androidSettings));
  }

  Future<void> scheduleHabitNotification(int id, String title, String body, int hour, int minute) async {
    final scheduledDate = _nextInstanceOfTime(hour, minute);
    await _notifications.zonedSchedule(
      1000 + id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'habits',
          'Habit Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelHabitNotification(int id) async {
    await _notifications.cancel(1000 + id);
  }

  Future<void> scheduleEventNotification(int id, String title, String body, DateTime scheduledDate) async {
    if (scheduledDate.isBefore(DateTime.now())) return;
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(android: AndroidNotificationDetails('events', 'Event Reminders')),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelEventNotification(int id) async {
    await _notifications.cancel(id);
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) scheduledDate = scheduledDate.add(const Duration(days: 1));
    return scheduledDate;
  }

  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> zonedSchedule(
    int id,
    String title,
    String body,
    tz.TZDateTime scheduledDate,
    NotificationDetails details, {
    AndroidScheduleMode androidScheduleMode = AndroidScheduleMode.exactAllowWhileIdle,
    DateTimeComponents? matchDateTimeComponents,
    UILocalNotificationDateInterpretation uiLocalNotificationDateInterpretation = UILocalNotificationDateInterpretation.absoluteTime,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: androidScheduleMode,
      matchDateTimeComponents: matchDateTimeComponents,
      uiLocalNotificationDateInterpretation: uiLocalNotificationDateInterpretation,
    );
  }
}