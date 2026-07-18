import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:personal_app/main.dart';
import 'package:personal_app/features/notes.dart';
import 'package:personal_app/features/habits.dart';
import 'package:personal_app/features/calendar.dart';
import 'package:personal_app/features/calculator.dart';
import 'package:personal_app/features/life.dart';
import 'package:personal_app/features/settings_provider.dart';
import 'package:personal_app/services/notification_service.dart';
import 'package:personal_app/database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNotificationService extends Mock implements NotificationService {}

class MockAppDatabase extends Mock implements AppDatabase {}

class MockDatabase extends Mock implements Database {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Mock local_auth platform channel globally to prevent hanging in tests
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/local_auth'),
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'canCheckBiometrics':
          return false;
        case 'isDeviceSupported':
          return true;
        case 'authenticate':
          return true;
        case 'getEnrolledBiometrics':
          return <String>[];
        default:
          return null;
      }
    },
  );

  late MockDatabase mockDb;
  late SharedPreferences testPrefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    testPrefs = await SharedPreferences.getInstance();

    mockDb = MockDatabase();
    final mockAppDb = MockAppDatabase();
    when(() => mockAppDb.database).thenAnswer((_) async => mockDb);
    AppDatabase.setInstanceForTesting(mockAppDb);

    when(
      () => mockDb.query(
        any(),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        orderBy: any(named: 'orderBy'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
    when(() => mockDb.rawQuery(any(), any())).thenAnswer((_) async => []);
    when(() => mockDb.insert(any(), any())).thenAnswer((_) async => 0);
    when(
      () => mockDb.update(
        any(),
        any(),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
      ),
    ).thenAnswer((_) async => 0);
    when(
      () => mockDb.delete(
        any(),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
      ),
    ).thenAnswer((_) async => 0);
  });

  tearDown(() {
    AppDatabase.clearInstanceForTesting();
  });

  Widget buildTestApp({Widget? child}) {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => NotesProvider()),
          ChangeNotifierProvider(
            create: (_) => HabitsProvider(MockNotificationService()),
          ),
          ChangeNotifierProvider(create: (_) => CalendarProvider()),
          ChangeNotifierProvider(create: (_) => CalculatorProvider()),
          ChangeNotifierProvider(create: (_) => LifeProvider()),
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(prefs: testPrefs),
          ),
        ],
        child: child ?? const MainScreen(),
      ),
    );
  }

  group('MainScreen', () {
    Future<void> navigateToTab(
      WidgetTester tester,
      String label,
      Type expectedScreen,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.toString().contains('overflowed')) {
          oldHandler?.call(details);
        }
      };
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.tap(find.text(label));
      await tester.pump();
      FlutterError.onError = oldHandler;
      expect(find.byType(expectedScreen), findsOneWidget);
    }

    testWidgets('Shows bottom navigation with 6 tabs', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(6));
      expect(find.text('Notes'), findsWidgets);
      expect(find.text('Habits'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Calculator'), findsOneWidget);
      expect(find.text('Life'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('Defaults to Notes tab', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      expect(find.byType(NotesScreen), findsOneWidget);
    });

    testWidgets('Uses a navigation rail on wide layouts', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('Can navigate to Habits tab', (WidgetTester tester) async {
      await navigateToTab(tester, 'Habits', HabitsScreen);
    });

    testWidgets('Can navigate to Calendar tab', (WidgetTester tester) async {
      await navigateToTab(tester, 'Calendar', CalendarScreen);
    });

    testWidgets('Can navigate to Calculator tab', (WidgetTester tester) async {
      await navigateToTab(tester, 'Calculator', CalculatorScreen);
    });

    testWidgets('Can navigate to Life tab', (WidgetTester tester) async {
      await navigateToTab(tester, 'Life', LifeScreen);
    });
  });

  group('NotesScreen', () {
    testWidgets('Shows FAB to create notes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => NotesProvider(),
            child: const NotesScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('Shows AppBar with Notes title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => NotesProvider(),
            child: const NotesScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Notes'), findsOneWidget);
    });

    testWidgets('Shows search icon in AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => NotesProvider(),
            child: const NotesScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });

  group('HabitsScreen', () {
    testWidgets('Renders populated habits without framework assertions', (
      WidgetTester tester,
    ) async {
      when(
        () => mockDb.query('habits', orderBy: any(named: 'orderBy')),
      ).thenAnswer(
        (_) async => [
          {
            'id': 1,
            'name': 'Exercise',
            'icon': 'fitness_center',
            'color': 0xFF6750A4,
            'reminder_time': null,
            'created_at': DateTime.now().toIso8601String(),
            'display_order': 0,
          },
        ],
      );
      when(() => mockDb.query('habit_logs')).thenAnswer((_) async => []);

      final errors = <String>[];
      final previousHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details.exceptionAsString());
        previousHandler?.call(details);
      };

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => HabitsProvider(MockNotificationService()),
            child: const HabitsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Exercise'), findsWidgets);
      expect(
        errors.where((error) => error.contains('_dependents.isEmpty')),
        isEmpty,
      );
      FlutterError.onError = previousHandler;
    });

    testWidgets('Shows empty state when no habits', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => HabitsProvider(MockNotificationService()),
            child: const HabitsScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No habits created yet'), findsOneWidget);
      expect(find.byIcon(Icons.checklist_rtl_rounded), findsOneWidget);
    });

    testWidgets('Shows add habit button in AppBar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => HabitsProvider(MockNotificationService()),
            child: const HabitsScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('Opens add habit dialog on button tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => HabitsProvider(MockNotificationService()),
            child: const HabitsScreen(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
      await tester.pump();

      expect(find.text('New Habit'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('CalculatorScreen', () {
    testWidgets('Shows calculator display with 0', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CalculatorProvider()),
              ChangeNotifierProvider(
                create: (_) => SettingsProvider(prefs: testPrefs),
              ),
            ],
            child: const CalculatorScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('0'), findsWidgets);
    });

    testWidgets('Shows memory buttons in scientific mode', (
      WidgetTester tester,
    ) async {
      final settings = SettingsProvider(prefs: testPrefs);
      settings.setScientificMode(true);
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CalculatorProvider()),
              ChangeNotifierProvider.value(value: settings),
            ],
            child: const CalculatorScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('MC'), findsOneWidget);
      expect(find.text('MR'), findsOneWidget);
      expect(find.text('M+'), findsOneWidget);
      expect(find.text('M-'), findsOneWidget);
    });

    testWidgets('Shows number buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CalculatorProvider()),
              ChangeNotifierProvider(
                create: (_) => SettingsProvider(prefs: testPrefs),
              ),
            ],
            child: const CalculatorScreen(),
          ),
        ),
      );
      await tester.pump();

      for (int i = 1; i <= 9; i++) {
        expect(find.text(i.toString()), findsOneWidget);
      }
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('Shows operator buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CalculatorProvider()),
              ChangeNotifierProvider(
                create: (_) => SettingsProvider(prefs: testPrefs),
              ),
            ],
            child: const CalculatorScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('÷'), findsOneWidget);
      expect(find.text('×'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
      expect(find.text('+'), findsOneWidget);
      expect(find.text('='), findsOneWidget);
    });

    testWidgets('Tapping number updates expression', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CalculatorProvider()),
              ChangeNotifierProvider(
                create: (_) => SettingsProvider(prefs: testPrefs),
              ),
            ],
            child: const CalculatorScreen(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('5'));
      await tester.pump();
      expect(find.text('5'), findsWidgets);
    });
  });

  group('LifeScreen', () {
    /// Helper: pump until LifeProvider finishes loading.
    Future<void> pumpUntilLoaded(WidgetTester tester, LifeProvider provider) async {
      int attempts = 0;
      while (provider.loading && attempts < 50) {
        await tester.pump(const Duration(milliseconds: 50));
        attempts++;
      }
    }

    testWidgets('Shows DOB entry when not set', (WidgetTester tester) async {
      // Create provider and wait for async init
      final provider = LifeProvider();
      await pumpUntilLoaded(tester, provider);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: provider,
            child: const LifeScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('How many days have you been alive?'), findsOneWidget);
      expect(find.text('Enter Date of Birth'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_empty_rounded), findsOneWidget);
    });

    testWidgets('Shows life metrics when DOB is set', (
      WidgetTester tester,
    ) async {
      final provider = LifeProvider();
      await provider.saveDOB(DateTime(1990, 5, 15));
      await pumpUntilLoaded(tester, provider);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: provider,
            child: const LifeScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('TIME ELAPSED SINCE BIRTH'), findsOneWidget);
      expect(find.text('Life Progress Meter'), findsOneWidget);
      expect(find.text('REAL-TIME LIFE METRICS'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('CalendarScreen', () {
    testWidgets('Shows month header with navigation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => HabitsProvider(MockNotificationService()),
              ),
              ChangeNotifierProvider(create: (_) => NotesProvider()),
              ChangeNotifierProvider(create: (_) => CalendarProvider()),
              ChangeNotifierProvider(
                create: (_) => SettingsProvider(prefs: testPrefs),
              ),
            ],
            child: const CalendarScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('Shows day names', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => HabitsProvider(MockNotificationService()),
              ),
              ChangeNotifierProvider(create: (_) => NotesProvider()),
              ChangeNotifierProvider(create: (_) => CalendarProvider()),
              ChangeNotifierProvider(
                create: (_) => SettingsProvider(prefs: testPrefs),
              ),
            ],
            child: const CalendarScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
    });

    testWidgets('Shows FAB for adding event', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => HabitsProvider(MockNotificationService()),
              ),
              ChangeNotifierProvider(create: (_) => NotesProvider()),
              ChangeNotifierProvider(create: (_) => CalendarProvider()),
              ChangeNotifierProvider(
                create: (_) => SettingsProvider(prefs: testPrefs),
              ),
            ],
            child: const CalendarScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('Shows search and filter buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => HabitsProvider(MockNotificationService()),
              ),
              ChangeNotifierProvider(create: (_) => NotesProvider()),
              ChangeNotifierProvider(create: (_) => CalendarProvider()),
              ChangeNotifierProvider(
                create: (_) => SettingsProvider(prefs: testPrefs),
              ),
            ],
            child: const CalendarScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
    });
  });
}
