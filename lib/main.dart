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

import 'theme/app_theme.dart';

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
            themeAnimationDuration: const Duration(milliseconds: 350),
            themeAnimationCurve: Curves.easeInOutCubic,
            localizationsDelegates: const [
              FlutterQuillLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            theme: AppTheme.lightTheme(theme.$2),
            darkTheme: AppTheme.darkTheme(theme.$2),
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

  static const List<Widget> _screens = [
    NotesScreen(key: ValueKey('NotesScreen')),
    HabitsScreen(key: ValueKey('HabitsScreen')),
    CalendarScreen(key: ValueKey('CalendarScreen')),
    CalculatorScreen(key: ValueKey('CalculatorScreen')),
    LifeScreen(key: ValueKey('LifeScreen')),
    SettingsScreen(key: ValueKey('SettingsScreen')),
  ];

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.description_outlined),
        selectedIcon: Icon(Icons.description_rounded),
        label: 'Notes',
        tooltip: 'Notes',
      ),
      NavigationDestination(
        icon: Icon(Icons.check_circle_outline_rounded),
        selectedIcon: Icon(Icons.check_circle_rounded),
        label: 'Habits',
        tooltip: 'Habits',
      ),
      NavigationDestination(
        icon: Icon(Icons.calendar_today_outlined),
        selectedIcon: Icon(Icons.calendar_month_rounded),
        label: 'Calendar',
        tooltip: 'Calendar',
      ),
      NavigationDestination(
        icon: Icon(Icons.calculate_outlined),
        selectedIcon: Icon(Icons.calculate_rounded),
        label: 'Calc',
        tooltip: 'Calc',
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

    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tab != 0) {
          HapticFeedback.selectionClick();
          setState(() => _tab = 0);
        }
      },
      child: LayoutBuilder(
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
                      backgroundColor: theme.colorScheme.surfaceContainer,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primaryContainer,
                                theme.colorScheme.primary.withValues(alpha: 0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.dashboard_rounded,
                            color: theme.colorScheme.onPrimary,
                            size: 24,
                          ),
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
                  Expanded(
                    child: IndexedStack(
                      index: _tab,
                      children: _screens,
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar:
                isWide
                    ? null
                    : Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                        ),
                        child: NavigationBar(
                          selectedIndex: _tab,
                          onDestinationSelected: _selectTab,
                          labelBehavior:
                              NavigationDestinationLabelBehavior.alwaysShow,
                          destinations: destinations,
                        ),
                      ),
          );
        },
      ),
    );
  }
}
