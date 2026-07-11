import 'package:sqflite/sqflite.dart';

/// Database migration strategy and version history:
///
/// Version 1 (Initial): Basic tables for notes, calendar_events, calculator_history
/// Version 2: Added habits, habit_logs, settings tables. Added color/tags to notes, category to calendar_events
/// Version 3: Added recurrence support to calendar_events (recurrence, recurrence_end columns)
/// Version 4: Added display_order column to habits for reordering
///
/// Migration Strategy:
/// - Use ALTER TABLE for additive schema changes (new columns with defaults)
/// - Use CREATE TABLE IF NOT EXISTS for new tables (idempotent)
/// - Wrap ALTER TABLE in try-catch to handle cases where column already exists
/// - Always increment version number when schema changes
/// - Test migrations by installing old version, then upgrading
///
/// Future migration guidelines:
/// - For breaking changes: create new table, migrate data, drop old table
/// - For new columns: ALTER TABLE ADD COLUMN with DEFAULT value
/// - For new tables: CREATE TABLE IF NOT EXISTS in onUpgrade
/// - Never delete columns in SQLite (not supported), mark as deprecated instead
/// - Keep onUpgrade handlers idempotent (use IF NOT EXISTS, try-catch)

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._();
  static Database? _db;
  AppDatabase._();

  static AppDatabase get instance => _instance;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/personal_app.db';
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
            notes TEXT DEFAULT '',
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
            icon TEXT NOT NULL DEFAULT 'star',
            reminder_time TEXT,
            display_order INTEGER NOT NULL DEFAULT 0,
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

        // Populate default habits
        final now = DateTime.now().toIso8601String();
        await db.insert('habits', {'name': 'Bathing', 'icon': 'bathtub', 'created_at': now});
        await db.insert('habits', {'name': 'Playing', 'icon': 'sports_esports', 'created_at': now});
        await db.insert('habits', {'name': 'Exercise', 'icon': 'fitness_center', 'created_at': now});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute("ALTER TABLE notes ADD COLUMN color INTEGER NOT NULL DEFAULT 4294967295");
            await db.execute("ALTER TABLE notes ADD COLUMN tags TEXT NOT NULL DEFAULT ''");
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE calendar_events ADD COLUMN category TEXT NOT NULL DEFAULT 'General'");
          } catch (_) {}
          
          await db.execute('''
            CREATE TABLE IF NOT EXISTS habits (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              icon TEXT NOT NULL DEFAULT 'star',
              reminder_time TEXT,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS habit_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              habit_id INTEGER NOT NULL,
              date TEXT NOT NULL,
              FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');

          // Populate default habits if not present
          final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM habits'));
          if (count == null || count == 0) {
            final now = DateTime.now().toIso8601String();
            await db.insert('habits', {'name': 'Bathing', 'icon': 'bathtub', 'created_at': now});
            await db.insert('habits', {'name': 'Playing', 'icon': 'sports_esports', 'created_at': now});
            await db.insert('habits', {'name': 'Exercise', 'icon': 'fitness_center', 'created_at': now});
          }
        }
        if (oldVersion < 3) {
          try {
            await db.execute("ALTER TABLE calendar_events ADD COLUMN recurrence TEXT DEFAULT 'none'");
            await db.execute("ALTER TABLE calendar_events ADD COLUMN recurrence_end TEXT");
          } catch (_) {}
        }
        if (oldVersion < 4) {
          try {
            await db.execute("ALTER TABLE habits ADD COLUMN display_order INTEGER NOT NULL DEFAULT 0");
          } catch (_) {}
        }
      },
    );
  }
}
