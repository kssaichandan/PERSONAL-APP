import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'database.dart';
import 'features/notes.dart';
import 'features/habits.dart';
import 'features/calendar.dart';
import 'features/calculator.dart';
import 'features/life.dart';
import 'features/settings.dart';
import 'features/settings_provider.dart';
import 'services/notification_service.dart';
import 'utils/snackbar_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database;
  final notificationService = NotificationService();
  await notificationService.initialize();
  try {
    await notificationService.rescheduleStoredNotifications();
  } catch (_) {
    // Notification setup must never prevent the app from opening.
  }
  runApp(PersonalApp(notificationService: notificationService));
}

class PersonalApp extends StatelessWidget {
  final NotificationService notificationService;
  const PersonalApp({super.key, required this.notificationService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create:
              (_) => NotesProvider(notificationService: notificationService),
        ),
        ChangeNotifierProvider(
          create: (_) => HabitsProvider(notificationService),
        ),
        ChangeNotifierProvider(
          create:
              (_) => CalendarProvider(notificationService: notificationService),
        ),
        ChangeNotifierProvider(create: (_) => CalculatorProvider()),
        ChangeNotifierProvider(create: (_) => LifeProvider()),
        ChangeNotifierProvider(
          create:
              (_) => SettingsProvider(notificationService: notificationService),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            scaffoldMessengerKey: scaffoldMessengerKey,
            title: 'Personal App',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              FlutterQuillLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            theme: ThemeData(
              colorSchemeSeed: settings.colorSeed,
              useMaterial3: true,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              colorSchemeSeed: settings.colorSeed,
              useMaterial3: true,
              brightness: Brightness.dark,
            ),
            themeMode: settings.themeMode,
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;

  static const _screens = <Widget>[
    NotesScreen(),
    HabitsScreen(),
    CalendarScreen(),
    CalculatorScreen(),
    LifeScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    const destinations = [
      NavigationDestination(icon: Icon(Icons.note_rounded), label: 'Notes'),
      NavigationDestination(
        icon: Icon(Icons.checklist_rtl_rounded),
        label: 'Habits',
      ),
      NavigationDestination(
        icon: Icon(Icons.calendar_month),
        label: 'Calendar',
      ),
      NavigationDestination(icon: Icon(Icons.calculate), label: 'Calculator'),
      NavigationDestination(
        icon: Icon(Icons.hourglass_empty_rounded),
        label: 'Life',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_rounded),
        label: 'Settings',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        return Scaffold(
          body: Row(
            children: [
              if (isWide)
                NavigationRail(
                  selectedIndex: _tab,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  labelType: NavigationRailLabelType.all,
                  destinations:
                      destinations
                          .map(
                            (destination) => NavigationRailDestination(
                              icon: destination.icon,
                              label: Text(destination.label),
                            ),
                          )
                          .toList(),
                ),
              Expanded(child: IndexedStack(index: _tab, children: _screens)),
            ],
          ),
          bottomNavigationBar:
              isWide
                  ? null
                  : NavigationBar(
                    selectedIndex: _tab,
                    onDestinationSelected: (i) => setState(() => _tab = i),
                    labelBehavior:
                        NavigationDestinationLabelBehavior.onlyShowSelected,
                    destinations: destinations,
                  ),
        );
      },
    );
  }
}
