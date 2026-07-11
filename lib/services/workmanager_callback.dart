import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

import '../database.dart';
import '../services/notification_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'rescheduleNotifications':
        return await _rescheduleAllNotifications();
      default:
        return Future.value(false);
    }
  });
}

Future<bool> _rescheduleAllNotifications() async {
  try {
    // Initialize database
    await AppDatabase.instance.database;
    
    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.initialize();
    
    final db = await AppDatabase.instance.database;
    
    // Reschedule calendar events
    final now = DateTime.now();
    final endDate = now.add(const Duration(days: 365));
    
    final eventMaps = await db.query(
      'calendar_events',
      where: 'date >= ? AND date <= ? AND time IS NOT NULL',
      whereArgs: [
        DateFormat('yyyy-MM-dd').format(now),
        DateFormat('yyyy-MM-dd').format(endDate),
      ],
    );
    
    for (final event in eventMaps) {
      final time = event['time'] as String?;
      if (time == null) continue;
      
      final parts = time.split(':');
      final scheduled = DateTime(
        DateTime.parse(event['date'] as String).year,
        DateTime.parse(event['date'] as String).month,
        DateTime.parse(event['date'] as String).day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      
      if (scheduled.isAfter(now)) {
        await notificationService.zonedSchedule(
          event['id'] as int,
          event['title'] as String,
          event['notes']?.isNotEmpty == true 
            ? event['notes'] as String 
            : 'Reminder for your scheduled event',
          tz.TZDateTime.from(scheduled, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails('events', 'Event Reminders'),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
    
    // Reschedule habit reminders
    final habitMaps = await db.query('habits', where: 'reminder_time IS NOT NULL');
    
    for (final habit in habitMaps) {
      final reminderTime = habit['reminder_time'] as String?;
      if (reminderTime == null) continue;
      
      final parts = reminderTime.split(':');
      await notificationService.zonedSchedule(
        1000 + (habit['id'] as int),
        'Habit Reminder: ${habit['name']}',
        'Time to complete your habit! Tap to log it.',
        _nextInstanceOfTime(int.parse(parts[0]), int.parse(parts[1])),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'habits', 'Habit Reminders', 
            importance: Importance.high, 
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
    
    return true;
  } catch (e) {
    return false;
  }
}

tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
  final now = tz.TZDateTime.now(tz.local);
  var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
  if (scheduledDate.isBefore(now)) scheduledDate = scheduledDate.add(const Duration(days: 1));
  return scheduledDate;
}