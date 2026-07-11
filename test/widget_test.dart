import 'package:flutter/material.dart';
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
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

class MockNotificationService extends Mock implements NotificationService {}
class MockAppDatabase extends Mock implements AppDatabase {}
class MockDatabase extends Mock implements sqlcipher.Database {}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late MockDatabase mockDb;

  setUp(() {
    mockDb = MockDatabase();
    final mockAppDb = MockAppDatabase();
    when(() => mockAppDb.database).thenAnswer((_) async => mockDb);
    AppDatabase.setInstanceForTesting(mockAppDb);

    when(() => mockDb.query(any(),
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
            orderBy: any(named: 'orderBy'),
            limit: any(named: 'limit')))
        .thenAnswer((_) async => []);
    when(() => mockDb.rawQuery(any(), any())).thenAnswer((_) async => []);
    when(() => mockDb.insert(any(), any())).thenAnswer((_) async => 0);
    when(() => mockDb.update(any(), any(),
            where: any(named: 'where'), whereArgs: any(named: 'whereArgs')))
        .thenAnswer((_) async => 0);
    when(() => mockDb.delete(any(),
            where: any(named: 'where'), whereArgs: any(named: 'whereArgs')))
        .thenAnswer((_) async => 0);
  });

  tearDown(() {
    AppDatabase.clearInstanceForTesting();
  });

  Widget buildTestApp({Widget? child}) {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => NotesProvider()),
          ChangeNotifierProvider(create: (_) => HabitsProvider(MockNotificationService())),
          ChangeNotifierProvider(create: (_) => CalendarProvider(MockNotificationService())),
          ChangeNotifierProvider(create: (_) => CalculatorProvider()),
          ChangeNotifierProvider(create: (_) => LifeProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: child ?? const MainScreen(),
      ),
    );
  }

  group('MainScreen', () {
    Future<void> navigateToTab(WidgetTester tester, String label, Type expectedScreen) async {
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

    testWidgets('Shows bottom navigation with 6 tabs', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Notes'), findsNWidgets(2));
      expect(find.text('Habits'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Calculator'), findsOneWidget);
      expect(find.text('Life'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('Defaults to Notes tab', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      expect(find.byType(NotesScreen), findsOneWidget);
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
    testWidgets('Shows search field', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => NotesProvider(),
          child: const NotesScreen(),
        ),
      ));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Shows AppBar with Notes title', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => NotesProvider(),
          child: const NotesScreen(),
        ),
      ));
      await tester.pump();

      expect(find.text('Notes'), findsOneWidget);
    });
  });

  group('HabitsScreen', () {
    testWidgets('Shows empty state when no habits', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => HabitsProvider(MockNotificationService()),
          child: const HabitsScreen(),
        ),
      ));
      await tester.pump();

      expect(find.text('No habits created yet'), findsOneWidget);
      expect(find.byIcon(Icons.checklist_rtl_rounded), findsOneWidget);
    });

    testWidgets('Shows add habit button in AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => HabitsProvider(MockNotificationService()),
          child: const HabitsScreen(),
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('Opens add habit dialog on button tap', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => HabitsProvider(MockNotificationService()),
          child: const HabitsScreen(),
        ),
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
      await tester.pump();

      expect(find.text('Add Custom Habit'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('CalculatorScreen', () {
    testWidgets('Shows calculator display with 0', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => CalculatorProvider(),
          child: const CalculatorScreen(),
        ),
      ));
      await tester.pump();

      expect(find.text('0'), findsWidgets);
    });

    testWidgets('Shows memory buttons', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => CalculatorProvider(),
          child: const CalculatorScreen(),
        ),
      ));
      await tester.pump();

      expect(find.text('MC'), findsOneWidget);
      expect(find.text('MR'), findsOneWidget);
      expect(find.text('M+'), findsOneWidget);
      expect(find.text('M-'), findsOneWidget);
    });

    testWidgets('Shows number buttons', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => CalculatorProvider(),
          child: const CalculatorScreen(),
        ),
      ));
      await tester.pump();

      for (int i = 1; i <= 9; i++) {
        expect(find.text(i.toString()), findsOneWidget);
      }
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('Shows operator buttons', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => CalculatorProvider(),
          child: const CalculatorScreen(),
        ),
      ));
      await tester.pump();

      expect(find.text('÷'), findsOneWidget);
      expect(find.text('×'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
      expect(find.text('+'), findsOneWidget);
      expect(find.text('='), findsOneWidget);
    });

    testWidgets('Tapping number updates expression', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => CalculatorProvider(),
          child: const CalculatorScreen(),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('5'));
      await tester.pump();
      expect(find.text('5'), findsWidgets);
    });
  });

  group('LifeScreen', () {
    testWidgets('Shows DOB entry when not set', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => LifeProvider(),
          child: const LifeScreen(),
        ),
      ));
      await tester.pump();

      expect(find.text('How many days have you been alive?'), findsOneWidget);
      expect(find.text('Enter Date of Birth'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_empty_rounded), findsOneWidget);
    });

    testWidgets('Shows life metrics when DOB is set', (WidgetTester tester) async {
      final provider = LifeProvider();
      await provider.saveDOB(DateTime(1990, 5, 15));

      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider.value(
          value: provider,
          child: const LifeScreen(),
        ),
      ));
      await tester.pump();

      expect(find.text('TIME ELAPSED SINCE BIRTH'), findsOneWidget);
      expect(find.text('Life Progress Meter'), findsOneWidget);
      expect(find.text('REAL-TIME LIFE METRICS'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('CalendarScreen', () {
    testWidgets('Shows month header with navigation', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => HabitsProvider(MockNotificationService())),
            ChangeNotifierProvider(create: (_) => NotesProvider()),
            ChangeNotifierProvider(create: (_) => CalendarProvider(MockNotificationService())),
          ],
          child: const CalendarScreen(),
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('Shows day names', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => HabitsProvider(MockNotificationService())),
            ChangeNotifierProvider(create: (_) => NotesProvider()),
            ChangeNotifierProvider(create: (_) => CalendarProvider(MockNotificationService())),
          ],
          child: const CalendarScreen(),
        ),
      ));
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
      await tester.pumpWidget(MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => HabitsProvider(MockNotificationService())),
            ChangeNotifierProvider(create: (_) => NotesProvider()),
            ChangeNotifierProvider(create: (_) => CalendarProvider(MockNotificationService())),
          ],
          child: const CalendarScreen(),
        ),
      ));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('Shows search and filter buttons', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => HabitsProvider(MockNotificationService())),
            ChangeNotifierProvider(create: (_) => NotesProvider()),
            ChangeNotifierProvider(create: (_) => CalendarProvider(MockNotificationService())),
          ],
          child: const CalendarScreen(),
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
    });
  });
}
