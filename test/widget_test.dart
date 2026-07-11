import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';

import '../lib/main.dart';
import '../lib/features/notes.dart';
import '../lib/features/habits.dart';
import '../lib/features/calendar.dart';
import '../lib/features/calculator.dart';
import '../lib/features/life.dart';
import '../lib/services/notification_service.dart';
import '../lib/database.dart';

// Mock classes
class MockNotificationService extends Mock implements NotificationService {}
class MockNotesProvider extends Mock implements NotesProvider {}
class MockHabitsProvider extends Mock implements HabitsProvider {}
class MockCalendarProvider extends Mock implements CalendarProvider {}
class MockCalculatorProvider extends Mock implements CalculatorProvider {}
class MockLifeProvider extends Mock implements LifeProvider {}

void main() {
  group('MainScreen', () {
    late MockNotificationService mockNotifications;
    late MockNotesProvider mockNotesProvider;
    late MockHabitsProvider mockHabitsProvider;
    late MockCalendarProvider mockCalendarProvider;
    late MockCalculatorProvider mockCalculatorProvider;
    late MockLifeProvider mockLifeProvider;

    setUp(() {
      mockNotifications = MockNotificationService();
      mockNotesProvider = MockNotesProvider();
      mockHabitsProvider = MockHabitsProvider();
      mockCalendarProvider = MockCalendarProvider();
      mockCalculatorProvider = MockCalculatorProvider();
      mockLifeProvider = MockLifeProvider();

      when(() => mockNotesProvider.notes).thenReturn([]);
      when(() => mockNotesProvider.loading).thenReturn(false);
      when(() => mockNotesProvider.error).thenReturn(null);
      when(() => mockNotesProvider.query).thenReturn('');
      when(() => mockNotesProvider.selectedTag).thenReturn('All');
      when(() => mockNotesProvider.allTags).thenReturn(['All']);
      when(() => mockNotesProvider.search(any())).thenReturn(null);
      when(() => mockNotesProvider.selectTag(any())).thenReturn(null);

      when(() => mockHabitsProvider.habits).thenReturn([]);
      when(() => mockHabitsProvider.loading).thenReturn(false);
      when(() => mockHabitsProvider.error).thenReturn(null);
      when(() => mockHabitsProvider.isCompleted(any(), any())).thenReturn(false);
      when(() => mockHabitsProvider.getStreaks(any())).thenReturn({'current': 0, 'max': 0});
      when(() => mockHabitsProvider.completionsInMonth(any(), any())).thenReturn(0);

      when(() => mockCalendarProvider.events).thenReturn([]);
      when(() => mockCalendarProvider.currentMonth).thenReturn(DateTime.now());
      when(() => mockCalendarProvider.loading).thenReturn(false);
      when(() => mockCalendarProvider.error).thenReturn(null);
      when(() => mockCalendarProvider.eventsForDay(any())).thenReturn([]);

      when(() => mockCalculatorProvider.expression).thenReturn('');
      when(() => mockCalculatorProvider.result).thenReturn('');
      when(() => mockCalculatorProvider.memory).thenReturn(0.0);
      when(() => mockCalculatorProvider.history).thenReturn([]);
      when(() => mockCalculatorProvider.error).thenReturn(null);

      when(() => mockLifeProvider.dob).thenReturn(null);
      when(() => mockLifeProvider.loading).thenReturn(false);
    });

    Widget createTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: mockNotesProvider),
          ChangeNotifierProvider.value(value: mockHabitsProvider),
          ChangeNotifierProvider.value(value: mockCalendarProvider),
          ChangeNotifierProvider.value(value: mockCalculatorProvider),
          ChangeNotifierProvider.value(value: mockLifeProvider),
        ],
        child: MaterialApp(
          home: MainScreen(),
        ),
      );
    }

    testWidgets('Shows bottom navigation with 5 tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Habits'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Calculator'), findsOneWidget);
      expect(find.text('Life'), findsOneWidget);
    });

    testWidgets('Defaults to Notes tab', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // The IndexedStack should show NotesScreen by default (index 0)
      expect(find.byType(NotesScreen), findsOneWidget);
    });

    testWidgets('Can navigate to Habits tab', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      await tester.tap(find.text('Habits').first);
      await tester.pumpAndSettle();
      
      expect(find.byType(HabitsScreen), findsOneWidget);
    });

    testWidgets('Can navigate to Calendar tab', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      await tester.tap(find.text('Calendar').first);
      await tester.pumpAndSettle();
      
      expect(find.byType(CalendarScreen), findsOneWidget);
    });

    testWidgets('Can navigate to Calculator tab', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      await tester.tap(find.text('Calculator').first);
      await tester.pumpAndSettle();
      
      expect(find.byType(CalculatorScreen), findsOneWidget);
    });

    testWidgets('Can navigate to Life tab', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      await tester.tap(find.text('Life').first);
      await tester.pumpAndSettle();
      
      expect(find.byType(LifeScreen), findsOneWidget);
    });
  });

  group('NotesScreen', () {
    late MockNotesProvider mockProvider;

    setUp(() {
      mockProvider = MockNotesProvider();
      when(() => mockProvider.notes).thenReturn([]);
      when(() => mockProvider.loading).thenReturn(false);
      when(() => mockProvider.error).thenReturn(null);
      when(() => mockProvider.query).thenReturn('');
      when(() => mockProvider.selectedTag).thenReturn('All');
      when(() => mockProvider.allTags).thenReturn(['All']);
      when(() => mockProvider.search(any())).thenReturn(null);
      when(() => mockProvider.selectTag(any())).thenReturn(null);
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: ChangeNotifierProvider.value(
          value: mockProvider,
          child: NotesScreen(),
        ),
      );
    }

    testWidgets('Shows empty state when no notes', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      expect(find.text('No notes yet'), findsOneWidget);
      expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
    });

    testWidgets('Shows search field', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search notes...'), findsOneWidget);
    });

    testWidgets('Shows FAB for adding note', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('Opens NoteEditorScreen on FAB tap', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      
      expect(find.byType(NoteEditorScreen), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
    });
  });

  group('HabitsScreen', () {
    late MockHabitsProvider mockProvider;

    setUp(() {
      mockProvider = MockHabitsProvider();
      when(() => mockProvider.habits).thenReturn([]);
      when(() => mockProvider.loading).thenReturn(false);
      when(() => mockProvider.error).thenReturn(null);
      when(() => mockProvider.isCompleted(any(), any())).thenReturn(false);
      when(() => mockProvider.getStreaks(any())).thenReturn({'current': 0, 'max': 0});
      when(() => mockProvider.completionsInMonth(any(), any())).thenReturn(0);
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: ChangeNotifierProvider.value(
          value: mockProvider,
          child: HabitsScreen(),
        ),
      );
    }

    testWidgets('Shows empty state when no habits', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      expect(find.text('No habits created yet'), findsOneWidget);
      expect(find.byIcon(Icons.checklist_rtl_rounded), findsOneWidget);
    });

    testWidgets('Shows add habit button in AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('Opens add habit dialog on button tap', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
      await tester.pumpAndSettle();
      
      expect(find.text('Add Custom Habit'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('CalculatorScreen', () {
    late MockCalculatorProvider mockProvider;

    setUp(() {
      mockProvider = MockCalculatorProvider();
      when(() => mockProvider.expression).thenReturn('');
      when(() => mockProvider.result).thenReturn('');
      when(() => mockProvider.memory).thenReturn(0.0);
      when(() => mockProvider.history).thenReturn([]);
      when(() => mockProvider.error).thenReturn(null);
      when(() => mockProvider.input(any())).thenReturn(null);
      when(() => mockProvider.memoryClear()).thenReturn(null);
      when(() => mockProvider.memoryRecall()).thenReturn(null);
      when(() => mockProvider.memoryAdd()).thenReturn(null);
      when(() => mockProvider.memorySubtract()).thenReturn(null);
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: ChangeNotifierProvider.value(
          value: mockProvider,
          child: CalculatorScreen(),
        ),
      );
    }

    testWidgets('Shows calculator display', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      expect(find.text('0'), findsWidgets); // Expression and result both show 0
    });

    testWidgets('Shows memory buttons', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      expect(find.text('MC'), findsOneWidget);
      expect(find.text('MR'), findsOneWidget);
      expect(find.text('M+'), findsOneWidget);
      expect(find.text('M-'), findsOneWidget);
    });

    testWidgets('Shows number buttons', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      for (int i = 0; i <= 9; i++) {
        expect(find.text(i.toString()), findsOneWidget);
      }
    });

    testWidgets('Shows operator buttons', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      expect(find.text('÷'), findsOneWidget);
      expect(find.text('×'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
      expect(find.text('+'), findsOneWidget);
      expect(find.text('='), findsOneWidget);
    });

    testWidgets('Shows history button when history exists', (WidgetTester tester) async {
      when(() => mockProvider.history).thenReturn([
        {'id': '1', 'expression': '2+2', 'result': '4'},
      ]);
      
      await tester.pumpWidget(createTestWidget());
      
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });
  });

  group('LifeScreen', () {
    late MockLifeProvider mockProvider;

    setUp(() {
      mockProvider = MockLifeProvider();
      when(() => mockProvider.dob).thenReturn(null);
      when(() => mockProvider.loading).thenReturn(false);
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: ChangeNotifierProvider.value(
          value: mockProvider,
          child: LifeScreen(),
        ),
      );
    }

    testWidgets('Shows DOB entry when not set', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      expect(find.text('How many days have you been alive?'), findsOneWidget);
      expect(find.text('Enter Date of Birth'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_empty_rounded), findsOneWidget);
    });

    testWidgets('Opens date picker on button tap', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      await tester.tap(find.text('Enter Date of Birth'));
      await tester.pumpAndSettle();
      
      // Date picker should appear
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('Shows life metrics when DOB is set', (WidgetTester tester) async {
      when(() => mockProvider.dob).thenReturn(DateTime(1990, 5, 15));
      
      await tester.pumpWidget(createTestWidget());
      
      expect(find.text('TIME ELAPSED SINCE BIRTH'), findsOneWidget);
      expect(find.text('Life Progress Meter'), findsOneWidget);
      expect(find.text('REAL-TIME LIFE METRICS'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('CalendarScreen', () {
    late MockCalendarProvider mockProvider;

    setUp(() {
      mockProvider = MockCalendarProvider();
      when(() => mockProvider.events).thenReturn([]);
      when(() => mockProvider.currentMonth).thenReturn(DateTime.now());
      when(() => mockProvider.loading).thenReturn(false);
      when(() => mockProvider.error).thenReturn(null);
      when(() => mockProvider.eventsForDay(any())).thenReturn([]);
      when(() => mockProvider.previousMonth()).thenReturn(null);
      when(() => mockProvider.nextMonth()).thenReturn(null);
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: ChangeNotifierProvider.value(
          value: mockProvider,
          child: CalendarScreen(),
        ),
      );
    }

    testWidgets('Shows month header with navigation', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('Shows day names', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
    });

    testWidgets('Shows FAB for adding event', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });
}