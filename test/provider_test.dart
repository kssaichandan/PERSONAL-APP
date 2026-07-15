import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_app/features/notes.dart';
import 'package:personal_app/features/habits.dart';
import 'package:personal_app/features/calendar.dart';
import 'package:personal_app/features/calculator.dart';
import 'package:personal_app/features/life.dart';
import 'package:personal_app/features/settings_provider.dart';
import 'package:personal_app/database.dart';
import 'package:personal_app/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class MockNotificationService extends Mock implements NotificationService {}

class MockDatabase extends Mock implements Database {}

class MockAppDatabase extends Mock implements AppDatabase {}

class FakeTZDateTime extends Fake implements tz.TZDateTime {}

class FakeNotificationDetails extends Fake implements NotificationDetails {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  tz_data.initializeTimeZones();
  setUpAll(() {
    registerFallbackValue(FakeTZDateTime());
    registerFallbackValue(FakeNotificationDetails());
    registerFallbackValue(AndroidScheduleMode.exactAllowWhileIdle);
    registerFallbackValue(UILocalNotificationDateInterpretation.absoluteTime);
  });

  late MockDatabase mockDb;
  late MockAppDatabase mockAppDb;

  setUp(() {
    mockDb = MockDatabase();
    mockAppDb = MockAppDatabase();
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

  group('CalculatorProvider Tests', () {
    late CalculatorProvider provider;

    setUp(() {
      provider = CalculatorProvider();
    });

    test('initial state has empty expression and result', () {
      expect(provider.expression, equals(''));
      expect(provider.result, equals(''));
    });

    test('input adds characters to expression', () {
      provider.input('5');
      provider.input('+');
      provider.input('3');
      expect(provider.expression, equals('5+3'));
    });

    test('clear resets expression and result', () {
      provider.input('5+3');
      provider.input('C');
      expect(provider.expression, equals(''));
      expect(provider.result, equals(''));
    });

    test('backspace removes last character', () {
      provider.input('123');
      provider.input('⌫');
      expect(provider.expression, equals('12'));
    });

    test('evaluate calculates result', () {
      provider.input('2+2');
      provider.input('=');
      expect(provider.result, equals('4'));
    });

    test('evaluate handles division', () {
      provider.input('10');
      provider.input('÷');
      provider.input('2');
      provider.input('=');
      expect(provider.result, equals('5'));
    });

    test('evaluate handles division by zero as Error', () {
      provider.input('5');
      provider.input('÷');
      provider.input('0');
      provider.input('=');
      expect(provider.result, equals('Error'));
    });

    test('evaluate handles decimal numbers', () {
      provider.input('1');
      provider.input('.');
      provider.input('5');
      provider.input('+');
      provider.input('2');
      provider.input('.');
      provider.input('5');
      provider.input('=');
      expect(provider.result, equals('4'));
    });

    test('evaluate handles complex expression with precedence', () {
      provider.input('2');
      provider.input('+');
      provider.input('3');
      provider.input('×');
      provider.input('4');
      provider.input('=');
      expect(provider.result, equals('14'));
    });

    test('memory functions work', () {
      provider.input('5');
      provider.input('+');
      provider.input('3');
      provider.input('=');
      expect(provider.result, equals('8'));

      provider.memoryAdd();
      expect(provider.memory, equals(8.0));

      provider.input('C');
      provider.input('2');
      provider.input('=');
      expect(provider.result, equals('2'));

      provider.memorySubtract();
      expect(provider.memory, equals(6.0));

      provider.memoryRecall();
      expect(provider.expression, contains('6'));

      provider.memoryClear();
      expect(provider.memory, equals(0.0));
    });

    test('sqrt function evaluates correctly', () {
      provider.input('sqrt(16)');
      provider.input('=');
      expect(provider.result, equals('4'));
    });

    test('log function evaluates correctly', () {
      provider.input('log(100)');
      provider.input('=');
      expect(provider.result, equals('2'));
    });

    test('percentage operator works as postfix', () {
      provider.input('50');
      provider.input('%');
      provider.input('=');
      expect(provider.result, equals('0.5'));
    });

    test('power operator works', () {
      provider.input('2');
      provider.input('^');
      provider.input('3');
      provider.input('=');
      expect(provider.result, equals('8'));
    });

    test('parentheses work correctly', () {
      provider.input('(');
      provider.input('1');
      provider.input('+');
      provider.input('2');
      provider.input(')');
      provider.input('×');
      provider.input('3');
      provider.input('=');
      expect(provider.result, equals('9'));
    });

    test('constants pi and e work', () {
      provider.input('π');
      provider.input('=');
      expect(double.parse(provider.result), closeTo(3.14159, 0.0001));

      provider.input('C');
      provider.input('e');
      provider.input('=');
      expect(double.parse(provider.result), closeTo(2.71828, 0.0001));
    });

    test('loadExpression sets expression', () {
      provider.loadExpression('2+2');
      expect(provider.expression, equals('2+2'));
      expect(provider.result, equals(''));
    });

    test('input is limited to 50 characters', () {
      for (int i = 0; i < 60; i++) {
        provider.input('1');
      }
      expect(provider.expression.length, equals(50));
    });
  });

  group('HabitsProvider Tests', () {
    late HabitsProvider provider;
    late MockNotificationService mockNotifications;

    setUp(() async {
      mockNotifications = MockNotificationService();
      when(() => mockNotifications.initialize()).thenAnswer((_) async {});
      provider = HabitsProvider(mockNotifications);
      await Future.delayed(Duration.zero);
    });

    test('initial state completes loading with empty data', () {
      expect(provider.loading, isFalse);
      expect(provider.habits, isEmpty);
    });

    test('isCompleted returns false for empty logs', () {
      expect(provider.isCompleted(1, DateTime.now()), isFalse);
    });

    test('getStreaks returns zeros for empty logs', () {
      final streaks = provider.getStreaks(1);
      expect(streaks['current'], equals(0));
      expect(streaks['max'], equals(0));
    });

    test('completionsInMonth returns 0 for empty logs', () {
      final count = provider.completionsInMonth(1, DateTime(2024, 1));
      expect(count, equals(0));
    });

    test('selection mode works', () {
      provider.toggleHabitSelection(1);
      expect(provider.isSelectionMode, isTrue);
      expect(provider.selectedHabits.contains(1), isTrue);

      provider.toggleHabitSelection(2);
      expect(provider.selectedHabits.length, equals(2));

      provider.toggleHabitSelection(1);
      expect(provider.selectedHabits.contains(1), isFalse);
      expect(provider.isSelectionMode, isTrue);

      provider.clearSelection();
      expect(provider.isSelectionMode, isFalse);
    });

    test('clearSelection clears all selected', () {
      provider.toggleHabitSelection(1);
      provider.toggleHabitSelection(2);
      provider.clearSelection();
      expect(provider.isSelectionMode, isFalse);
      expect(provider.selectedHabits, isEmpty);
    });

    test('deleteMultiple with empty set does nothing', () async {
      await provider.deleteMultiple({});
      expect(provider.loading, isFalse);
    });

    test(
      'saving a habit with a reminder schedules a daily notification',
      () async {
        when(
          () => mockNotifications.zonedSchedule(
            any(),
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
            uiLocalNotificationDateInterpretation: any(
              named: 'uiLocalNotificationDateInterpretation',
            ),
          ),
        ).thenAnswer((_) async {});

        await provider.saveHabit(
          'Drink water',
          'water_drop',
          0xFF6750A4,
          '08:30',
        );

        verify(
          () => mockNotifications.zonedSchedule(
            1000,
            'Habit Reminder: Drink water',
            'Time to complete your habit! Tap to log it.',
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            matchDateTimeComponents: DateTimeComponents.time,
            uiLocalNotificationDateInterpretation: any(
              named: 'uiLocalNotificationDateInterpretation',
            ),
          ),
        ).called(1);
      },
    );
  });

  group('Notification Settings Tests', () {
    test(
      'disabling notifications cancels all scheduled notifications',
      () async {
        final notifications = MockNotificationService();
        when(() => notifications.cancelAll()).thenAnswer((_) async {});
        final settings = SettingsProvider(notificationService: notifications);

        await settings.setNotificationsEnabled(false);

        verify(() => notifications.cancelAll()).called(1);
      },
    );
  });

  group('CalendarProvider Tests', () {
    late CalendarProvider provider;
    late MockNotificationService mockNotifications;

    setUp(() async {
      mockNotifications = MockNotificationService();
      when(() => mockNotifications.initialize()).thenAnswer((_) async {});
      provider = CalendarProvider();
      await Future.delayed(Duration.zero);
    });

    test('initial state completes loading with empty data', () {
      expect(provider.loading, isFalse);
      expect(provider.events, isEmpty);
    });

    test('search filters events by query', () {
      provider.setSearchQuery('test');
      expect(provider.searchQuery, equals('test'));
      provider.clearSearch();
      expect(provider.searchQuery, equals(''));
    });

    test('categoryFilter filters events by category', () {
      provider.setCategoryFilter('Work');
      expect(provider.categoryFilter, equals('Work'));
      provider.clearCategoryFilter();
      expect(provider.categoryFilter, equals('all'));
    });

    test('filteredEvents returns empty when no events', () {
      expect(provider.filteredEvents, isEmpty);
    });

    test('eventsForDay returns empty for no events', () {
      final dayEvents = provider.eventsForDay(DateTime(2024, 1, 15));
      expect(dayEvents, isEmpty);
    });

    test('navigation updates current month', () {
      final initial = provider.currentMonth;
      provider.nextMonth();
      expect(
        provider.currentMonth.month,
        equals(initial.month == 12 ? 1 : initial.month + 1),
      );

      provider.previousMonth();
      provider.previousMonth();
      expect(
        provider.currentMonth.month,
        equals(initial.month == 1 ? 11 : initial.month - 1),
      );
    });
  });

  group('LifeProvider Tests', () {
    late LifeProvider provider;

    setUp(() async {
      provider = LifeProvider();
      await Future.delayed(Duration.zero);
    });

    test('initial state loads with defaults', () {
      expect(provider.loading, isFalse);
      expect(provider.dob, isNull);
      expect(provider.lifeExpectancy, equals(80));
    });

    test('setLifeExpectancy validates range', () async {
      await provider.setLifeExpectancy(90);
      expect(provider.lifeExpectancy, equals(90));

      await provider.setLifeExpectancy(0);
      expect(provider.lifeExpectancy, equals(90));

      await provider.setLifeExpectancy(150);
      expect(provider.lifeExpectancy, equals(90));

      await provider.setLifeExpectancy(-1);
      expect(provider.lifeExpectancy, equals(90));
    });

    test('setBiometricEnabled toggles state', () async {
      await provider.setBiometricEnabled(true);
      expect(provider.biometricEnabled, isTrue);

      await provider.setBiometricEnabled(false);
      expect(provider.biometricEnabled, isFalse);
    });

    test('saveDOB sets dob', () async {
      final dob = DateTime(1990, 5, 15);
      await provider.saveDOB(dob);
      expect(provider.dob, equals(dob));
    });

    test('resetDOB clears dob', () async {
      await provider.saveDOB(DateTime(1990, 5, 15));
      expect(provider.dob, isNotNull);

      await provider.resetDOB();
      expect(provider.dob, isNull);
    });
  });

  group('NotesProvider Tests', () {
    late NotesProvider provider;

    setUp(() async {
      provider = NotesProvider();
      await Future.delayed(Duration.zero);
    });

    test('initial state completes loading with empty data', () {
      expect(provider.loading, isFalse);
      expect(provider.notes, isEmpty);
    });

    test('search filters notes by query', () {
      provider.search('test');
      expect(provider.query, equals('test'));
    });

    test('selection mode works correctly', () {
      provider.toggleSelection(1);
      expect(provider.isSelectionMode, isTrue);
      expect(provider.selectedNotes.contains(1), isTrue);

      provider.toggleSelection(1);
      expect(provider.isSelectionMode, isFalse);
      expect(provider.selectedNotes.contains(1), isFalse);
    });

    test('clearSelection clears all selected', () {
      provider.toggleSelection(1);
      provider.toggleSelection(2);
      provider.clearSelection();
      expect(provider.isSelectionMode, isFalse);
      expect(provider.selectedNotes, isEmpty);
    });
  });
}
