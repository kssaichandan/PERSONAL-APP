import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database.dart';
import 'features/notes.dart';
import 'features/habits.dart';
import 'features/calendar.dart';
import 'features/calculator.dart';
import 'features/life.dart';
import 'features/settings.dart';
import 'features/settings_provider.dart';
import 'features/onboarding.dart';
import 'services/notification_service.dart';
import 'utils/snackbar_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await AppDatabase.instance.database;
  final notificationService = NotificationService();
  try {
    await notificationService.initialize();
    await notificationService.rescheduleStoredNotifications();
  } catch (_) {
    // Notification setup must never prevent the app from opening.
  }
  runApp(PersonalApp(notificationService: notificationService, prefs: prefs));
}

class PersonalApp extends StatelessWidget {
  final NotificationService notificationService;
  final SharedPreferences prefs;
  const PersonalApp({
    super.key,
    required this.notificationService,
    required this.prefs,
  });

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
              (_) => SettingsProvider(
                notificationService: notificationService,
                prefs: prefs,
              ),
        ),
      ],
      child: Selector<SettingsProvider, (ThemeMode, Color)>(
        selector: (_, s) => (s.themeMode, s.colorSeed),
        builder: (context, theme, _) {
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
              colorSchemeSeed: theme.$2,
              useMaterial3: true,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              colorSchemeSeed: theme.$2,
              useMaterial3: true,
              brightness: Brightness.dark,
            ),
            themeMode: theme.$1,
            home:
                prefs.getBool('onboarding_complete_v1') ?? false
                    ? const MainScreen()
                    : const OnboardingScreen(),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final settings = context.read<SettingsProvider>();
        if (settings.notificationsEnabled) {
          settings.requestNotificationPermissions();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const NotesScreen(),
      const HabitsScreen(),
      const CalendarScreen(),
      const CalculatorScreen(),
      const LifeScreen(),
      const SettingsScreen(),
    ];

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
              Expanded(child: IndexedStack(index: _tab, children: screens)),
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
