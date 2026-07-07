import 'package:sqflite/sqflite.dart';

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
          CREATE TABLE note_recordings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            note_id INTEGER NOT NULL,
            file_path TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE
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
            CREATE TABLE IF NOT EXISTS note_recordings (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              note_id INTEGER NOT NULL,
              file_path TEXT NOT NULL,
              duration_seconds INTEGER NOT NULL,
              created_at TEXT NOT NULL,
              FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE
            )
          ''');
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
      },
    );
  }
}
