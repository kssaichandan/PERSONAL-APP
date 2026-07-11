import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

import '../lib/database.dart';
import '../lib/features/notes.dart';
import '../lib/features/habits.dart';
import '../lib/features/calendar.dart';
import '../lib/features/calculator.dart';
import '../lib/features/life.dart';
import '../lib/services/notification_service.dart';

// Mock classes
class MockDatabase extends Mock implements Database {}
class MockNotificationService extends Mock implements NotificationService {}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AppDatabase', () {
    late Database db;
    late String path;

    setUp(() async {
      path = await getDatabasesPath();
      path = join(path, 'test_personal_app.db');
      await deleteDatabase(path);
      db = await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE notes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL DEFAULT '',
              content TEXT NOT NULL DEFAULT '',
              pinned INTEGER NOT NULL DEFAULT 0,
              color INTEGER NOT NULL DEFAULT 4294967295,
              tags TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE calendar_events (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              date TEXT NOT NULL,
              time TEXT,
              category TEXT NOT NULL DEFAULT 'General',
              notes TEXT DEFAULT ''
            )
          ''');
          await db.execute('''
            CREATE TABLE calculator_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              expression TEXT NOT NULL,
              result TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE habits (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              icon TEXT NOT NULL DEFAULT 'star',
              reminder_time TEXT,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE habit_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              habit_id INTEGER NOT NULL,
              date TEXT NOT NULL,
              FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        },
      );
    });

    tearDown(() async {
      await db.close();
      await deleteDatabase(path);
    });

    test('Database creates all tables', () async {
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tables.map((t) => t['name'] as String).toSet();
      expect(tableNames, containsAll(['notes', 'calendar_events', 'calculator_history', 'habits', 'habit_logs', 'settings']));
    });

    test('Can insert and query notes', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('notes', {
        'title': 'Test Note',
        'content': 'Test Content',
        'pinned': 0,
        'color': 0xFFFFFFFF,
        'tags': 'tag1,tag2',
        'created_at': now,
        'updated_at': now,
      });

      final results = await db.query('notes');
      expect(results.length, 1);
      expect(results.first['title'], 'Test Note');
      expect(results.first['content'], 'Test Content');
    });

    test('Can insert and query habits', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('habits', {
        'name': 'Exercise',
        'icon': 'fitness_center',
        'reminder_time': '07:00',
        'created_at': now,
      });

      final results = await db.query('habits');
      expect(results.length, 1);
      expect(results.first['name'], 'Exercise');
      expect(results.first['reminder_time'], '07:00');
    });

    test('Can insert and query calendar events', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('calendar_events', {
        'title': 'Meeting',
        'date': '2026-07-15',
        'time': '14:30',
        'category': 'Work',
        'notes': 'Team sync',
      });

      final results = await db.query('calendar_events');
      expect(results.length, 1);
      expect(results.first['title'], 'Meeting');
      expect(results.first['category'], 'Work');
    });

    test('Can insert and query calculator history', () async {
      await db.insert('calculator_history', {
        'expression': '2 + 2',
        'result': '4',
        'created_at': DateTime.now().toIso8601String(),
      });

      final results = await db.query('calculator_history');
      expect(results.length, 1);
      expect(results.first['expression'], '2 + 2');
      expect(results.first['result'], '4');
    });

    test('Foreign key constraint on habit_logs', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('habits', {
        'name': 'Test Habit',
        'icon': 'star',
        'created_at': now,
      });

      await db.insert('habit_logs', {
        'habit_id': 1,
        'date': '2026-07-10',
      });

      final logs = await db.query('habit_logs');
      expect(logs.length, 1);
      expect(logs.first['habit_id'], 1);
    });
  });

  group('NotesProvider', () {
    late Database db;
    late String path;
    late NotesProvider provider;

    setUp(() async {
      path = await getDatabasesPath();
      path = join(path, 'test_notes.db');
      await deleteDatabase(path);
      db = await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE notes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL DEFAULT '',
              content TEXT NOT NULL DEFAULT '',
              pinned INTEGER NOT NULL DEFAULT 0,
              color INTEGER NOT NULL DEFAULT 4294967295,
              tags TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        },
      );
      
      // Override the database instance for testing
      AppDatabase._instance._db = db;
      provider = NotesProvider();
      await Future.delayed(Duration(milliseconds: 100)); // Wait for load
    });

    tearDown(() async {
      provider.dispose();
      await db.close();
      await deleteDatabase(path);
    });

    test('Initial state is loading', () {
      expect(provider.loading, true);
    });

    test('Loads notes from database', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('notes', {
        'title': 'Test Note',
        'content': 'Test Content',
        'pinned': 0,
        'color': 0xFFFFFFFF,
        'tags': '',
        'created_at': now,
        'updated_at': now,
      });

      provider.load();
      await Future.delayed(Duration(milliseconds: 100));

      expect(provider.loading, false);
      expect(provider.notes.length, 1);
      expect(provider.notes.first.title, 'Test Note');
    });

    test('Saves new note', () async {
      final note = Note(
        title: 'New Note',
        content: 'New Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await provider.save(note);
      expect(id, greaterThan(0));

      await Future.delayed(Duration(milliseconds: 100));
      expect(provider.notes.length, 1);
      expect(provider.notes.first.title, 'New Note');
    });

    test('Updates existing note', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('notes', {
        'title': 'Original',
        'content': 'Original Content',
        'pinned': 0,
        'color': 0xFFFFFFFF,
        'tags': '',
        'created_at': now,
        'updated_at': now,
      });

      provider.load();
      await Future.delayed(Duration(milliseconds: 100));

      final note = provider.notes.first;
      final updatedNote = Note(
        id: note.id,
        title: 'Updated',
        content: 'Updated Content',
        color: note.color,
        pinned: note.pinned,
        tags: note.tags,
        createdAt: note.createdAt,
        updatedAt: DateTime.now(),
      );

      await provider.save(updatedNote);
      await Future.delayed(Duration(milliseconds: 100));

      expect(provider.notes.first.title, 'Updated');
      expect(provider.notes.first.content, 'Updated Content');
    });

    test('Deletes note', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('notes', {
        'title': 'To Delete',
        'content': 'Delete Me',
        'pinned': 0,
        'color': 0xFFFFFFFF,
        'tags': '',
        'created_at': now,
        'updated_at': now,
      });

      provider.load();
      await Future.delayed(Duration(milliseconds: 100));
      expect(provider.notes.length, 1);

      await provider.delete(provider.notes.first.id!);
      await Future.delayed(Duration(milliseconds: 100));

      expect(provider.notes.length, 0);
    });

    test('Toggles pin status', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('notes', {
        'title': 'Test',
        'content': 'Content',
        'pinned': 0,
        'color': 0xFFFFFFFF,
        'tags': '',
        'created_at': now,
        'updated_at': now,
      });

      provider.load();
      await Future.delayed(Duration(milliseconds: 100));

      final note = provider.notes.first;
      expect(note.pinned, false);

      await provider.togglePin(note);
      await Future.delayed(Duration(milliseconds: 100));

      expect(provider.notes.first.pinned, true);
    });

    test('Search filters notes', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('notes', {
        'title': 'Apple Note',
        'content': 'About apples',
        'pinned': 0,
        'color': 0xFFFFFFFF,
        'tags': 'fruit',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('notes', {
        'title': 'Banana Note',
        'content': 'About bananas',
        'pinned': 0,
        'color': 0xFFFFFFFF,
        'tags': 'fruit',
        'created_at': now,
        'updated_at': now,
      });

      provider.load();
      await Future.delayed(Duration(milliseconds: 100));

      provider.search('Apple');
      expect(provider.notes.length, 1);
      expect(provider.notes.first.title, 'Apple Note');

      provider.search('');
      expect(provider.notes.length, 2);
    });

    test('Tag filtering works', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('notes', {
        'title': 'Note 1',
        'content': 'Content',
        'pinned': 0,
        'color': 0xFFFFFFFF,
        'tags': 'work,personal',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('notes', {
        'title': 'Note 2',
        'content': 'Content',
        'pinned': 0,
        'color': 0xFFFFFFFF,
        'tags': 'personal',
        'created_at': now,
        'updated_at': now,
      });

      provider.load();
      await Future.delayed(Duration(milliseconds: 100));

      provider.selectTag('work');
      expect(provider.notes.length, 1);
      expect(provider.notes.first.title, 'Note 1');

      provider.selectTag('All');
      expect(provider.notes.length, 2);
    });
  });

  group('CalculatorProvider', () {
    late CalculatorProvider provider;

    setUp(() {
      provider = CalculatorProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('Initial state is empty', () {
      expect(provider.expression, '');
      expect(provider.result, '');
      expect(provider.memory, 0.0);
      expect(provider.history, isEmpty);
    });

    test('Input numbers and operators', () {
      provider.input('1');
      provider.input('+');
      provider.input('2');
      
      expect(provider.expression, '1+2');
    });

    test('Evaluates simple expression', () {
      provider.input('1');
      provider.input('+');
      provider.input('2');
      provider.input('=');
      
      expect(provider.result, '3');
      expect(provider.expression, '3');
    });

    test('Evaluates complex expression with precedence', () {
      provider.input('2');
      provider.input('+');
      provider.input('3');
      provider.input('×');
      provider.input('4');
      provider.input('=');
      
      expect(provider.result, '14'); // 2 + (3 × 4) = 14
    });

    test('Handles parentheses', () {
      provider.input('(');
      provider.input('1');
      provider.input('+');
      provider.input('2');
      provider.input(')');
      provider.input('×');
      provider.input('3');
      provider.input('=');
      
      expect(provider.result, '9'); // (1+2) × 3 = 9
    });

    test('Handles functions', () {
      provider.input('s');
      provider.input('i');
      provider.input('n');
      provider.input('(');
      provider.input('0');
      provider.input(')');
      provider.input('=');
      
      expect(provider.result, '0');
    });

    test('Handles constants', () {
      provider.input('π');
      provider.input('=');
      
      expect(provider.result, '3.141592653589793');
    });

    test('Clears with C', () {
      provider.input('1');
      provider.input('+');
      provider.input('2');
      provider.input('C');
      
      expect(provider.expression, '');
      expect(provider.result, '');
    });

    test('Backspace works', () {
      provider.input('1');
      provider.input('2');
      provider.input('3');
      provider.input('⌫');
      
      expect(provider.expression, '12');
    });

    test('Memory functions', () {
      provider.input('5');
      provider.input('=');
      provider.memoryAdd();
      expect(provider.memory, 5.0);
      
      provider.memoryRecall();
      expect(provider.expression, '5');
      
      provider.memorySubtract();
      expect(provider.memory, 0.0);
      
      provider.memoryClear();
      expect(provider.memory, 0.0);
    });

    test('Handles error state', () {
      provider.input('1');
      provider.input('÷');
      provider.input('0');
      provider.input('=');
      
      expect(provider.result, 'Error');
    });

    test('Clears error on new input', () {
      provider.input('1');
      provider.input('÷');
      provider.input('0');
      provider.input('=');
      expect(provider.result, 'Error');
      
      provider.input('5');
      expect(provider.expression, '5');
      expect(provider.result, '');
    });

    test('Load history', () async {
      // Test that history loads without error
      await provider.loadHistory();
      expect(provider.history, isA<List>());
    });
  });

  group('HabitsProvider', () {
    late Database db;
    late String path;
    late HabitsProvider provider;
    late MockNotificationService mockNotifications;

    setUp(() async {
      path = await getDatabasesPath();
      path = join(path, 'test_habits.db');
      await deleteDatabase(path);
      db = await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE habits (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              icon TEXT NOT NULL DEFAULT 'star',
              reminder_time TEXT,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE habit_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              habit_id INTEGER NOT NULL,
              date TEXT NOT NULL,
              FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE
            )
          ''');
        },
      );
      
      mockNotifications = MockNotificationService();
      AppDatabase._instance._db = db;
      provider = HabitsProvider(mockNotifications);
      await Future.delayed(Duration(milliseconds: 100));
    });

    tearDown(() async {
      provider.dispose();
      await db.close();
      await deleteDatabase(path);
    });

    test('Initial state is loading', () {
      expect(provider.loading, true);
    });

    test('Loads habits from database', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('habits', {
        'name': 'Exercise',
        'icon': 'fitness_center',
        'reminder_time': '07:00',
        'created_at': now,
      });

      provider.load();
      await Future.delayed(Duration(milliseconds: 100));

      expect(provider.loading, false);
      expect(provider.habits.length, 1);
      expect(provider.habits.first.name, 'Exercise');
      expect(provider.habits.first.reminderTime, '07:00');
    });

    test('Creates new habit', () async {
      await provider.saveHabit('Reading', 'book', '20:00');
      await Future.delayed(Duration(milliseconds: 100));

      expect(provider.habits.length, 1);
      expect(provider.habits.first.name, 'Reading');
      expect(provider.habits.first.icon, 'book');
    });

    test('Deletes habit', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('habits', {
        'name': 'To Delete',
        'icon': 'star',
        'created_at': now,
      });

      provider.load();
      await Future.delayed(Duration(milliseconds: 100));
      expect(provider.habits.length, 1);

      await provider.deleteHabit(provider.habits.first.id!);
      await Future.delayed(Duration(milliseconds: 100));

      expect(provider.habits.length, 0);
    });

    test('Toggles habit log', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('habits', {
        'name': 'Test Habit',
        'icon': 'star',
        'created_at': now,
      });

      provider.load();
      await Future.delayed(Duration(milliseconds: 100));

      final habit = provider.habits.first;
      final today = DateTime.now();
      
      expect(provider.isCompleted(habit.id!, today), false);
      
      await provider.toggleLog(habit.id!, today);
      expect(provider.isCompleted(habit.id!, today), true);
      
      await provider.toggleLog(habit.id!, today);
      expect(provider.isCompleted(habit.id!, today), false);
    });

    test('Calculates streaks', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('habits', {
        'name': 'Streak Habit',
        'icon': 'star',
        'created_at': now,
      });

      provider.load();
      await Future.delayed(Duration(milliseconds: 100));

      final habit = provider.habits.first;
      final today = DateTime.now();
      final yesterday = today.subtract(Duration(days: 1));
      final dayBefore = today.subtract(Duration(days: 2));

      await provider.toggleLog(habit.id!, dayBefore);
      await provider.toggleLog(habit.id!, yesterday);
      await provider.toggleLog(habit.id!, today);

      final streaks = provider.getStreaks(habit.id!);
      expect(streaks['current'], 3);
      expect(streaks['max'], 3);
    });

    test('Updates reminder', () async {
      await provider.saveHabit('Test', 'star', null);
      await Future.delayed(Duration(milliseconds: 100));

      final habit = provider.habits.first;
      await provider.updateReminder(habit.id!, '08:00');
      await Future.delayed(Duration(milliseconds: 100));

      expect(provider.habits.first.reminderTime, '08:00');
    });
  });

  group('CalendarProvider', () {
    late Database db;
    late String path;
    late CalendarProvider provider;
    late MockNotificationService mockNotifications;

    setUp(() async {
      path = await getDatabasesPath();
      path = join(path, 'test_calendar.db');
      await deleteDatabase(path);
      db = await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE calendar_events (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              date TEXT NOT NULL,
              time TEXT,
              category TEXT NOT NULL DEFAULT 'General',
              notes TEXT DEFAULT ''
            )
          ''');
        },
      );
      
      mockNotifications = MockNotificationService();
      AppDatabase._instance._db = db;
      provider = CalendarProvider(mockNotifications);
      await Future.delayed(Duration(milliseconds: 100));
    });

    tearDown(() async {
      provider.dispose();
      await db.close();
      await deleteDatabase(path);
    });

    test('Initial state is loading', () {
      expect(provider.loading, true);
    });

    test('Loads events for current month', () async {
      final now = DateTime.now();
      await db.insert('calendar_events', {
        'title': 'Meeting',
        'date': '${now.year}-${now.month.toString().padLeft(2, '0')}-15',
        'time': '14:30',
        'category': 'Work',
        'notes': 'Team sync',
      });

      provider.load();
      await Future.delayed(Duration(milliseconds: 100));

      expect(provider.loading, false);
      expect(provider.events.length, 1);
      expect(provider.events.first.title, 'Meeting');
      expect(provider.events.first.category, 'Work');
    });

    test('Creates new event', () async {
      final now = DateTime.now();
      final event = CalendarEvent(
        title: 'New Event',
        date: now,
        time: '10:00',
        category: 'Personal',
        notes: 'Notes here',
      );

      await provider.save(event);
      await Future.delayed(Duration(milliseconds: 100));

      expect(provider.events.length, 1);
      expect(provider.events.first.title, 'New Event');
    });

    test('Updates existing event', () async {
      final now = DateTime.now();
      await db.insert('calendar_events', {
        'title': 'Original',
        'date': '${now.year}-${now.month.toString().padLeft(2, '0')}-15',
        'time': '10:00',
        'category': 'General',
        'notes': '',
      });

      provider.load();
      await Future.delayed(Duration(milliseconds: 100));

      final event = provider.events.first;
      final updated = CalendarEvent(
        id: event.id,
        title: 'Updated',
        date: event.date,
        time: event.time,
        category: event.category,
        notes: event.notes,
      );

      await provider.save(updated);
      await Future.delayed(Duration(milliseconds: 100));

      expect(provider.events.first.title, 'Updated');
    });

    test('Deletes event', () async {
      final now = DateTime.now();
      await db.insert('calendar_events', {
        'title': 'To Delete',
        'date': '${now.year}-${now.month.toString().padLeft(2, '0')}-15',
        'time': '10:00',
        'category': 'General',
        'notes': '',
      });

      provider.load();
      await Future.delayed(Duration(milliseconds: 100));
      expect(provider.events.length, 1);

      await provider.delete(provider.events.first.id!);
      await Future.delayed(Duration(milliseconds: 100));

      expect(provider.events.length, 0);
    });

    test('Filters events for specific day', () async {
      final now = DateTime.now();
      final date1 = DateTime(now.year, now.month, 10);
      final date2 = DateTime(now.year, now.month, 15);

      await db.insert('calendar_events', {
        'title': 'Event 1',
        'date': '${date1.year}-${date1.month.toString().padLeft(2, '0')}-${date1.day.toString().padLeft(2, '0')}',
        'time': '10:00',
        'category': 'General',
        'notes': '',
      });
      await db.insert('calendar_events', {
        'title': 'Event 2',
        'date': '${date2.year}-${date2.month.toString().padLeft(2, '0')}-${date2.day.toString().padLeft(2, '0')}',
        'time': '14:00',
        'category': 'General',
        'notes': '',
      });

      provider.load();
      await Future.delayed(Duration(milliseconds: 100));

      final day10Events = provider.eventsForDay(date1);
      expect(day10Events.length, 1);
      expect(day10Events.first.title, 'Event 1');

      final day15Events = provider.eventsForDay(date2);
      expect(day15Events.length, 1);
      expect(day15Events.first.title, 'Event 2');
    });

    test('Navigates months', () {
      final originalMonth = provider.currentMonth;
      provider.nextMonth();
      expect(provider.currentMonth.month, originalMonth.month + 1);
      
      provider.previousMonth();
      expect(provider.currentMonth.month, originalMonth.month);
    });
  });

  group('LifeProvider', () {
    late Database db;
    late String path;
    late LifeProvider provider;

    setUp(() async {
      path = await getDatabasesPath();
      path = join(path, 'test_life.db');
      await deleteDatabase(path);
      db = await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        },
      );
      
      AppDatabase._instance._db = db;
      provider = LifeProvider();
      await Future.delayed(Duration(milliseconds: 100));
    });

    tearDown(() async {
      provider.dispose();
      await db.close();
      await deleteDatabase(path);
    });

    test('Initial state is loading', () {
      expect(provider.loading, true);
    });

    test('Loads DOB from settings', () async {
      await db.insert('settings', {'key': 'dob', 'value': '1990-05-15'});

      provider.loadDOB();
      await Future.delayed(Duration(milliseconds: 100));

      expect(provider.loading, false);
      expect(provider.dob, isNotNull);
      expect(provider.dob!.year, 1990);
      expect(provider.dob!.month, 5);
      expect(provider.dob!.day, 15);
    });

    test('Saves DOB', () async {
      final date = DateTime(1995, 12, 25);
      await provider.saveDOB(date);
      await Future.delayed(Duration(milliseconds: 100));

      expect(provider.dob, isNotNull);
      expect(provider.dob!.year, 1995);
      expect(provider.dob!.month, 12);
      expect(provider.dob!.day, 25);

      // Verify persisted
      final maps = await db.query('settings', where: 'key = ?', whereArgs: ['dob']);
      expect(maps.length, 1);
      expect(maps.first['value'], '1995-12-25');
    });

    test('Resets DOB', () async {
      await db.insert('settings', {'key': 'dob', 'value': '1990-05-15'});
      provider.loadDOB();
      await Future.delayed(Duration(milliseconds: 100));
      expect(provider.dob, isNotNull);

      await provider.resetDOB();
      await Future.delayed(Duration(milliseconds: 100));

      expect(provider.dob, isNull);

      final maps = await db.query('settings', where: 'key = ?', whereArgs: ['dob']);
      expect(maps.length, 0);
    });
  });
}