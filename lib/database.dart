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
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL DEFAULT '',
            content TEXT NOT NULL DEFAULT '',
            pinned INTEGER NOT NULL DEFAULT 0,
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
            color INTEGER DEFAULT 0xFF6750A4,
            reminder_time TEXT,
            reminder_days TEXT,
            created_at TEXT NOT NULL,
            display_order INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE habit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            habit_id INTEGER NOT NULL,
            date TEXT NOT NULL,
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
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE notes ADD COLUMN favorite INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE notes ADD COLUMN color INTEGER');
          await db.execute('ALTER TABLE notes ADD COLUMN archived INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE notes ADD COLUMN deleted_at TEXT');
          await db.execute('ALTER TABLE notes ADD COLUMN reminder_time TEXT');
          await db.execute('ALTER TABLE notes ADD COLUMN priority INTEGER NOT NULL DEFAULT 0');
        }
      },
    );
  }
}
