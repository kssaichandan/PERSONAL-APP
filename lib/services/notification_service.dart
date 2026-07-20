import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../database.dart';

/// Owns Android notification setup and all persisted reminder scheduling.
///
/// The service intentionally falls back to an inexact alarm when Android has
/// not granted exact-alarm access. This keeps a reminder scheduled instead of
/// failing silently on Android 12 and later.
class NotificationService {
  static const _timeZoneChannel = MethodChannel('personal_app/timezone');

  static const _habitChannel = 'personal_app_habits_v2';
  static const _eventChannel = 'personal_app_events_v2';
  static const _noteChannel = 'personal_app_notes_v2';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _notificationPermissionRequested = false;
  bool _exactAlarmPermissionRequested = false;

  FlutterLocalNotificationsPlugin get notifications => _notifications;

  static const habitDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _habitChannel,
      'Habit reminders',
      channelDescription: 'Reminders for your habits',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
  );

  static const eventDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _eventChannel,
      'Event reminders',
      channelDescription: 'Reminders for your calendar events',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
  );

  static const noteDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _noteChannel,
      'Note reminders',
      channelDescription: 'Reminders for your notes',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
  );

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    await _configureLocalTimeZone();

    const androidSettings = AndroidInitializationSettings('ic_launcher');
    await _notifications.initialize(
      const InitializationSettings(android: androidSettings),
    );

    final android = _android;
    if (android != null) {
      await Future.wait([
        android.createNotificationChannel(
          const AndroidNotificationChannel(
            _habitChannel,
            'Habit reminders',
            description: 'Reminders for your habits',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        ),
        android.createNotificationChannel(
          const AndroidNotificationChannel(
            _eventChannel,
            'Event reminders',
            description: 'Reminders for your calendar events',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        ),
        android.createNotificationChannel(
          const AndroidNotificationChannel(
            _noteChannel,
            'Note reminders',
            description: 'Reminders for your notes',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        ),
      ]);
    }
    _initialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  Future<void> _configureLocalTimeZone() async {
    try {
      final name = await _timeZoneChannel.invokeMethod<String>('getTimeZone');
      if (name != null && name.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(name));
        return;
      }
    } catch (_) {
      // The channel is Android-only. The offset fallback below keeps the app
      // usable on other supported platforms and in widget tests.
    }

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
  }

  /// Requests Android's notification permission when it is needed.
  /// Returns false when the user has declined it.
  Future<bool> requestPermissions() async {
    final android = _android;
    if (android == null) return true;

    final alreadyEnabled = await android.areNotificationsEnabled();
    if (alreadyEnabled ?? false) return true;
    if (_notificationPermissionRequested) return false;

    _notificationPermissionRequested = true;
    return await android.requestNotificationsPermission() ?? false;
  }

  /// Requests exact-alarm access when Android requires it.
  ///
  /// A false result is not fatal: [zonedSchedule] uses an inexact,
  /// battery-friendly alarm instead so the reminder still arrives.
  Future<bool> requestExactAlarmPermission() async {
    final android = _android;
    if (android == null) return true;

    final alreadyAllowed = await android.canScheduleExactNotifications();
    if (alreadyAllowed ?? false) return true;
    if (_exactAlarmPermissionRequested) return false;

    _exactAlarmPermissionRequested = true;
    try {
      return await android.requestExactAlarmsPermission() ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> cancel(int id) => _notifications.cancel(id);

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
        final time = _parseTime(reminder);
        if (id == null || time == null) continue;
        await zonedSchedule(
          1000 + id,
          'Habit Reminder: ${habit['name']}',
          'Time to complete your habit! Tap to log it.',
          _nextDailyTime(time.$1, time.$2),
          habitDetails,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } else {
      await cancelHabitReminders();
    }

    if (prefs.getBool('event_reminders_enabled') ?? true) {
      final today = DateTime.now();
      final todayValue =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final events = await db.query(
        'calendar_events',
        where: 'date >= ?',
        whereArgs: [todayValue],
      );
      for (final event in events) {
        final id = event['id'] as int?;
        final dateValue = event['date'] as String?;
        final date = DateTime.tryParse(dateValue ?? '');
        if (id == null || date == null) continue;
        final time = _parseTime(event['time'] as String?) ?? (9, 0);
        final scheduled = tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day,
          time.$1,
          time.$2,
        );
        if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) continue;
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
              : 'Calendar event reminder',
          scheduled,
          eventDetails,
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
      final reminder = DateTime.tryParse(reminderValue ?? '');
      if (id == null || reminder == null) continue;
      final scheduled = tz.TZDateTime.from(reminder, tz.local);
      if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) continue;
      await zonedSchedule(
        5000 + id,
        'Note Reminder: ${note['title']}',
        (note['content'] as String?) ?? '',
        scheduled,
        noteDetails,
      );
    }
  }

  (int, int)? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return (hour, minute);
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
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Schedules an exact alarm when allowed, otherwise a reliable inexact one.
  /// Scheduling failures are caught so a platform error never reaches Flutter's
  /// red error screen.
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
    await initialize();
    final notificationsAllowed = await requestPermissions();
    if (!notificationsAllowed) return;

    final exactAllowed = await requestExactAlarmPermission();
    final scheduleMode =
        exactAllowed
            ? androidScheduleMode
            : AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: matchDateTimeComponents,
        uiLocalNotificationDateInterpretation:
            uiLocalNotificationDateInterpretation,
      );
    } on PlatformException {
      // A manufacturer may still reject an exact alarm after permission has
      // changed. Preserve the reminder with the inexact scheduler.
      if (scheduleMode == AndroidScheduleMode.inexactAllowWhileIdle) return;
      try {
        await _notifications.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: matchDateTimeComponents,
          uiLocalNotificationDateInterpretation:
              uiLocalNotificationDateInterpretation,
        );
      } on PlatformException {
        // The app remains usable; the next save or app launch retries it.
      }
    }
  }
}
