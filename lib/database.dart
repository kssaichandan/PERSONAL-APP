import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._();
  static Database? _db;
  static AppDatabase? _testInstance;
  AppDatabase._();

  static AppDatabase get instance => _testInstance ?? _instance;

  static void setInstanceForTesting(AppDatabase testDb) {
    _testInstance = testDb;
  }

  static void clearInstanceForTesting() {
    _testInstance = null;
    _db = null;
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'personal_app.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL DEFAULT '',
            content TEXT NOT NULL DEFAULT '',
            pinned INTEGER NOT NULL DEFAULT 0,
            favorite INTEGER NOT NULL DEFAULT 0,
            color INTEGER,
            archived INTEGER NOT NULL DEFAULT 0,
            deleted_at TEXT,
            reminder_time TEXT,
            priority INTEGER NOT NULL DEFAULT 0,
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
            notes TEXT DEFAULT '',
            category TEXT DEFAULT 'General',
            recurrence TEXT DEFAULT 'none',
            recurrence_end TEXT
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
            icon TEXT DEFAULT 'star',
            color INTEGER DEFAULT 4284993700,
            reminder_time TEXT,
            reminder_days TEXT,
            created_at TEXT NOT NULL,
            display_order INTEGER DEFAULT 0,
            habit_type TEXT NOT NULL DEFAULT 'yes_no',
            target_count INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE habit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            habit_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            count INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          // Alter notes table to add new columns if they do not exist
          final notesColumns = {
            'favorite': 'INTEGER NOT NULL DEFAULT 0',
            'color': 'INTEGER',
            'archived': 'INTEGER NOT NULL DEFAULT 0',
            'deleted_at': 'TEXT',
            'reminder_time': 'TEXT',
            'priority': 'INTEGER NOT NULL DEFAULT 0',
          };
          for (final entry in notesColumns.entries) {
            try {
              await db.execute(
                'ALTER TABLE notes ADD COLUMN ${entry.key} ${entry.value}',
              );
            } catch (_) {}
          }

          // Alter habits table to add new columns if they do not exist
          final habitsColumns = {
            'color': 'INTEGER DEFAULT 4284993700',
            'display_order': 'INTEGER DEFAULT 0',
          };
          for (final entry in habitsColumns.entries) {
            try {
              await db.execute(
                'ALTER TABLE habits ADD COLUMN ${entry.key} ${entry.value}',
              );
            } catch (_) {}
          }

          // Alter calendar_events table to add new columns if they do not exist
          final calendarColumns = {
            'notes': "TEXT DEFAULT ''",
            'category': "TEXT DEFAULT 'General'",
            'recurrence': "TEXT DEFAULT 'none'",
            'recurrence_end': 'TEXT',
          };
          for (final entry in calendarColumns.entries) {
            try {
              await db.execute(
                'ALTER TABLE calendar_events ADD COLUMN ${entry.key} ${entry.value}',
              );
            } catch (_) {}
          }
        }
        if (oldVersion < 4) {
          try {
            await db.execute(
              "ALTER TABLE habits ADD COLUMN habit_type TEXT NOT NULL DEFAULT 'yes_no'",
            );
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE habits ADD COLUMN target_count INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE habit_logs ADD COLUMN count INTEGER NOT NULL DEFAULT 1',
            );
          } catch (_) {}
        }
      },
    );
  }
}
