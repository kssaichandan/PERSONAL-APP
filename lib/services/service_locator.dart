import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database.dart';
import 'features/notes.dart';
import 'features/habits.dart';
import 'features/calendar.dart';
import 'features/calculator.dart';
import 'features/life.dart';
import 'services/notification_service.dart';

final serviceLocator = GetIt.instance;

Future<void> setupServiceLocator() async {
  // External dependencies
  final prefs = await SharedPreferences.getInstance();
  serviceLocator.registerSingleton<SharedPreferences>(prefs);
  
  // Core services
  serviceLocator.registerLazySingleton<AppDatabase>(() => AppDatabase.instance);
  serviceLocator.registerLazySingleton<NotificationService>(() => NotificationService());
  
  // Initialize notification service
  await serviceLocator<NotificationService>().initialize();
  
  // Providers
  serviceLocator.registerFactory<NotesProvider>(() => NotesProvider());
  serviceLocator.registerFactory<CalendarProvider>(() => CalendarProvider(serviceLocator<NotificationService>()));
  serviceLocator.registerFactory<CalculatorProvider>(() => CalculatorProvider());
  serviceLocator.registerFactory<HabitsProvider>(() => HabitsProvider(serviceLocator<NotificationService>()));
  serviceLocator.registerFactory<LifeProvider>(() => LifeProvider());
}