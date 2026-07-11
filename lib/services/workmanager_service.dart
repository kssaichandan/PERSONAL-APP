import 'package:workmanager/workmanager.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String rescheduleNotificationsTask = 'rescheduleNotificationsTask';

final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    tz.initializeTimeZones();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await notifications.initialize(const InitializationSettings(android: androidSettings));
    
    // Reschedule all pending notifications from database
    // This would need access to the database
    // For now, just re-initialize the plugin
    return Future.value(true);
  });
}

Future<void> setupWorkmanager() async {
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );
  
  await Workmanager().registerPeriodicTask(
    rescheduleNotificationsTask,
    rescheduleNotificationsTask,
    frequency: const Duration(hours: 24),
    constraints: Constraints(
      networkType: NetworkType.notRequired,
      requiresCharging: false,
    ),
  );
}