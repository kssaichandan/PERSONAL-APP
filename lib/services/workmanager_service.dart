import 'package:workmanager/workmanager.dart';

const String rescheduleNotificationsTask = 'rescheduleNotifications';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // This is handled by workmanager_callback.dart
    return Future.value(true);
  });
}

Future<void> setupWorkmanager() async {
  await Workmanager().initialize(
    callbackDispatcher,
  );
  
  await Workmanager().registerPeriodicTask(
    rescheduleNotificationsTask,
    rescheduleNotificationsTask,
    frequency: const Duration(hours: 24),
    constraints: Constraints(
      networkType: NetworkType.unmetered,
      requiresCharging: false,
    ),
  );
}