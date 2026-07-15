import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../database.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _permissionRequested = false;

  FlutterLocalNotificationsPlugin get notifications => _notifications;

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    final now = DateTime.now();
    tz.setLocalLocation(
      tz.Location('device', [-8640000000000000], [0], [
        tz.TimeZone(
          now.timeZoneOffset.inMilliseconds,
          isDst: false,
          abbreviation: now.timeZoneName,
        ),
      ]),
    );
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    await _notifications.initialize(
      const InitializationSettings(android: androidSettings),
    );
  }

  Future<void> requestPermissions() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    final android =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await android?.requestNotificationsPermission();
  }

  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAll() => _notifications.cancelAll();

  Future<void> cancelHabitReminders() => _cancelRows('habits', 1000);

  Future<void> cancelNoteReminders() => _cancelRows('notes', 5000);

  Future<void> cancelEventReminders() => _cancelRows('calendar_events', 10000);

  Future<void> _cancelRows(String table, int offset) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(table, columns: ['id']);
    for (final row in rows) {
      final id = row['id'] as int?;
      if (id != null) await cancel(offset + id);
    }
  }

  Future<void> rescheduleStoredNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    if (!notificationsEnabled) {
      await cancelAll();
      return;
    }

    final db = await AppDatabase.instance.database;
    if (prefs.getBool('habit_reminders_enabled') ?? true) {
      final habits = await db.query(
        'habits',
        columns: ['id', 'name', 'reminder_time'],
      );
      for (final habit in habits) {
        final id = habit['id'] as int?;
        final reminder = habit['reminder_time'] as String?;
        if (id == null || reminder == null) continue;
        final parts = reminder.split(':');
        if (parts.length != 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;
        await zonedSchedule(
          1000 + id,
          'Habit Reminder: ${habit['name']}',
          'Time to complete your habit! Tap to log it.',
          _nextDailyTime(hour, minute),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'habits',
              'Habit Reminders',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } else {
      await cancelHabitReminders();
    }

    if (prefs.getBool('event_reminders_enabled') ?? true) {
      final today = DateTime.now();
      final events = await db.query(
        'calendar_events',
        where: 'date >= ?',
        whereArgs: [
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
        ],
      );
      for (final event in events) {
        final id = event['id'] as int?;
        final dateValue = event['date'] as String?;
        if (id == null || dateValue == null) continue;
        final date = DateTime.tryParse(dateValue);
        if (date == null) continue;
        final time = event['time'] as String?;
        final parts = time?.split(':');
        final hour = parts != null ? int.tryParse(parts[0]) : 9;
        final minute =
            parts != null && parts.length > 1 ? int.tryParse(parts[1]) : 0;
        if (hour == null || minute == null) continue;
        final scheduled = tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );
        if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) continue;
        final recurrenceComponents = switch (event['recurrence'] as String?) {
          'daily' => DateTimeComponents.time,
          'weekly' => DateTimeComponents.dayOfWeekAndTime,
          'monthly' => DateTimeComponents.dayOfMonthAndTime,
          _ => null,
        };
        await zonedSchedule(
          10000 + id,
          'Event Alert: ${event['title']}',
          (event['notes'] as String?)?.isNotEmpty == true
              ? event['notes'] as String
              : 'Calendar Event Today',
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'calendar',
              'Event Reminders',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          matchDateTimeComponents: recurrenceComponents,
        );
      }
    } else {
      await cancelEventReminders();
    }

    final notes = await db.query('notes', where: 'reminder_time IS NOT NULL');
    for (final note in notes) {
      final id = note['id'] as int?;
      final reminderValue = note['reminder_time'] as String?;
      if (id == null || reminderValue == null) continue;
      final reminder = DateTime.tryParse(reminderValue);
      if (reminder == null) continue;
      final scheduled = tz.TZDateTime.from(reminder, tz.local);
      if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) continue;
      await zonedSchedule(
        5000 + id,
        'Note Reminder: ${note['title']}',
        (note['content'] as String?) ?? '',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails('notes', 'Note Reminders'),
        ),
      );
    }
  }

  tz.TZDateTime _nextDailyTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> zonedSchedule(
    int id,
    String title,
    String body,
    tz.TZDateTime scheduledDate,
    NotificationDetails details, {
    AndroidScheduleMode androidScheduleMode =
        AndroidScheduleMode.exactAllowWhileIdle,
    DateTimeComponents? matchDateTimeComponents,
    UILocalNotificationDateInterpretation
        uiLocalNotificationDateInterpretation =
        UILocalNotificationDateInterpretation.absoluteTime,
  }) async {
    await requestPermissions();
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: androidScheduleMode,
      matchDateTimeComponents: matchDateTimeComponents,
      uiLocalNotificationDateInterpretation:
          uiLocalNotificationDateInterpretation,
    );
  }
}
