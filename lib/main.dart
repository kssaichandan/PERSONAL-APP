import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  } catch (_) {}
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

  void _selectTab(int index) {
    if (index != _tab) {
      HapticFeedback.selectionClick();
      setState(() => _tab = index);
    }
  }

  Widget _buildCurrentScreen() {
    switch (_tab) {
      case 0:
        return const NotesScreen();
      case 1:
        return const HabitsScreen();
      case 2:
        return const CalendarScreen();
      case 3:
        return const CalculatorScreen();
      case 4:
        return const LifeScreen();
      case 5:
        return const SettingsScreen();
      default:
        return const NotesScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.note_rounded),
        selectedIcon: Icon(Icons.note_rounded),
        label: 'Notes',
        tooltip: 'Notes',
      ),
      NavigationDestination(
        icon: Icon(Icons.checklist_rtl_rounded),
        selectedIcon: Icon(Icons.checklist_rtl_rounded),
        label: 'Habits',
        tooltip: 'Habits',
      ),
      NavigationDestination(
        icon: Icon(Icons.calendar_month_rounded),
        selectedIcon: Icon(Icons.calendar_month_rounded),
        label: 'Calendar',
        tooltip: 'Calendar',
      ),
      NavigationDestination(
        icon: Icon(Icons.calculate_rounded),
        selectedIcon: Icon(Icons.calculate_rounded),
        label: 'Calculator',
        tooltip: 'Calculator',
      ),
      NavigationDestination(
        icon: Icon(Icons.hourglass_empty_rounded),
        selectedIcon: Icon(Icons.hourglass_full_rounded),
        label: 'Life',
        tooltip: 'Life Journey',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings_rounded),
        label: 'Settings',
        tooltip: 'Settings',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (isWide)
                  NavigationRail(
                    selectedIndex: _tab,
                    onDestinationSelected: _selectTab,
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: theme.colorScheme.surface,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Icon(
                        Icons.dashboard_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    destinations:
                        destinations
                            .map(
                              (destination) => NavigationRailDestination(
                                icon: destination.icon,
                                selectedIcon: destination.selectedIcon,
                                label: Text(destination.label),
                              ),
                            )
                            .toList(),
                  ),
                Expanded(child: _buildCurrentScreen()),
              ],
            ),
          ),
          bottomNavigationBar:
              isWide
                  ? null
                  : NavigationBar(
                    selectedIndex: _tab,
                    onDestinationSelected: _selectTab,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    height: 80,
                    destinations: destinations,
                  ),
        );
      },
    );
  }
}
