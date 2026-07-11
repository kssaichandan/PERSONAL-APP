import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'features/notes.dart';
import 'features/habits.dart';
import 'features/calendar.dart';
import 'features/calculator.dart';
import 'features/life.dart';
import 'features/settings.dart';
import 'features/settings_provider.dart';
import 'services/notification_service.dart';
import 'services/service_locator.dart';
import 'services/workmanager_callback.dart';

const _onboardingCompleteKey = 'onboarding_complete_v1';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await setupServiceLocator();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    'rescheduleNotifications',
    'rescheduleNotifications',
    frequency: const Duration(hours: 24),
    constraints: Constraints(networkType: NetworkType.unmetered),
  );

  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool(_onboardingCompleteKey) ?? false;

  // Request notification permission for Android 13+
  // Moved to MainScreen._requestNotificationPermission with rationale dialog

  runApp(PersonalApp(showOnboarding: !onboardingComplete));
}

class PersonalApp extends StatelessWidget {
  final bool showOnboarding;
  const PersonalApp({super.key, this.showOnboarding = false});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider(serviceLocator<NotificationService>())),
        ChangeNotifierProvider(create: (_) => CalculatorProvider()),
        ChangeNotifierProvider(create: (_) => HabitsProvider(serviceLocator<NotificationService>())),
        ChangeNotifierProvider(create: (_) => LifeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp(
        title: 'Personal App',
        debugShowCheckedModeBanner: false,
        theme: _appTheme(Brightness.light),
        darkTheme: _appTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: showOnboarding ? const OnboardingScreen() : const MainScreen(),
      ),
    );
  }

  ThemeData _appTheme(Brightness brightness) => ThemeData(
    colorSchemeSeed: Colors.deepPurple,
    useMaterial3: true,
    brightness: brightness,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(fontSize: 16),
      bodyMedium: TextStyle(fontSize: 14),
      bodySmall: TextStyle(fontSize: 12),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(fontSize: 10),
    ),
  );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.note_alt_rounded,
      title: 'Notes',
      description: 'Capture your thoughts, ideas, and important information with rich text notes. Add colors, tags, and pin your favorites.',
    ),
    OnboardingPage(
      icon: Icons.checklist_rtl_rounded,
      title: 'Habits',
      description: 'Build better habits with daily tracking, streaks, and reminders. Visualize your progress with weekly and monthly views.',
    ),
    OnboardingPage(
      icon: Icons.calendar_month_rounded,
      title: 'Calendar',
      description: 'Schedule events, set reminders, and see your habits and notes in a unified calendar view.',
    ),
    OnboardingPage(
      icon: Icons.calculate_rounded,
      title: 'Calculator',
      description: 'A powerful calculator with history, memory functions, and scientific mode for all your calculations.',
    ),
    OnboardingPage(
      icon: Icons.hourglass_empty_rounded,
      title: 'Life Tracker',
      description: 'See your life in perspective. Track days, weeks, months, and years since birth with a live progress meter.',
    ),
    OnboardingPage(
      icon: Icons.settings_rounded,
      title: 'Settings',
      description: 'Customize your experience with themes, notification preferences, data export/import, and more.',
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete_v1', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) => _pages[index],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? theme.colorScheme.primary : theme.colorScheme.outline,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _currentPage == _pages.length - 1 ? _completeOnboarding : () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (_currentPage != _pages.length - 1)
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: Text('Skip', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const OnboardingPage({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 60, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 32),
          Text(title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(description, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
        ],
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

  final _screens = const [
    NotesScreen(),
    HabitsScreen(),
    CalendarScreen(),
    CalculatorScreen(),
    LifeScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermission();
    });
  }

  Future<void> _requestNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.notifications_active_outlined, color: Theme.of(ctx).colorScheme.primary, size: 32),
          title: const Text('Enable Notifications?'),
          content: const Text(
            'We\'d like to send you notifications for habit reminders and calendar events. '
            'You can change this anytime in Settings.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enable')),
          ],
        ),
      );
      if (proceed == true && mounted) {
        final status = await Permission.notification.request();
        if (status.isPermanentlyDenied && mounted) {
          await openAppSettings();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            selectedIcon: Icon(Icons.note_alt_rounded),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_rtl_outlined),
            selectedIcon: Icon(Icons.checklist_rtl_rounded),
            label: 'Habits',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate_rounded),
            label: 'Calculator',
          ),
          NavigationDestination(
            icon: Icon(Icons.hourglass_empty_outlined),
            selectedIcon: Icon(Icons.hourglass_full_rounded),
            label: 'Life',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}