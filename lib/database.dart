import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

/// Database migration strategy and version history:
///
/// Version 1 (Initial): Basic tables for notes, calendar_events, calculator_history
/// Version 2: Added habits, habit_logs, settings tables. Added color/tags to notes, category to calendar_events
/// Version 3: Added recurrence support to calendar_events (recurrence, recurrence_end columns)
/// Version 4: Added display_order column to habits for reordering
/// Version 5: Migration to SQLCipher encrypted database
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
  static sqlcipher.Database? _db;
  static const _encryptionKeyKey = 'db_encryption_key';
  static const _migrationDoneKey = 'db_migration_v5_done';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  AppDatabase._();

  static AppDatabase get instance => _testInstance ?? _instance;

  /// Test-only: override the database instance for unit tests
  static void setInstanceForTesting(AppDatabase mock) {
    _testInstance = mock;
  }

  /// Test-only: clear the test override and reset state
  static void clearInstanceForTesting() {
    _testInstance = null;
    _db = null;
  }

  static AppDatabase? _testInstance;

  Future<sqlcipher.Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<sqlcipher.Database> _init() async {
    final dbPath = await sqlcipher.getDatabasesPath();
    final path = join(dbPath, 'personal_app.db');

    // Check if we need to migrate from plaintext to encrypted
    final needsMigration = await _needsMigration();
    if (needsMigration) {
      await _migrateToEncrypted(path);
    }

    final encryptionKey = await _getOrCreateEncryptionKey();

    return sqlcipher.openDatabase(
      path,
      version: 5,
      password: encryptionKey,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA cipher_page_size = 4096');
        await db.execute('PRAGMA kdf_iter = 256000');
      },
    );
  }

  Future<bool> _needsMigration() async {
    // Check if migration to v5 has been done
    final prefs = await _secureStorage.read(key: _migrationDoneKey);
    return prefs != 'true';
  }

  Future<void> _migrateToEncrypted(String newPath) async {
    final dbPath = await sqflite.getDatabasesPath();
    final oldPath = join(dbPath, 'personal_app.db');

    // Check if old plaintext database exists
    final oldDbFile = File(oldPath);
    if (!await oldDbFile.exists()) {
      // No old database, nothing to migrate
      await _secureStorage.write(key: _migrationDoneKey, value: 'true');
      return;
    }

    // Get or create encryption key
    final encryptionKey = await _getOrCreateEncryptionKey();

    // Open old plaintext database
    final oldDb = await sqlcipher.openDatabase(
      oldPath,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    try {
      // Read all data from old database
      final notes = await oldDb.query('notes');
      final events = await oldDb.query('calendar_events');
      final calcHistory = await oldDb.query('calculator_history');
      final habits = await oldDb.query('habits');
      final habitLogs = await oldDb.query('habit_logs');
      final settings = await oldDb.query('settings');

      await oldDb.close();

      // Delete old database file
      await oldDbFile.delete();

      // Create new encrypted database with all data
      final newDb = await sqlcipher.openDatabase(
        newPath,
        version: 5,
        password: encryptionKey,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: (db) async {
          await db.execute('PRAGMA cipher_page_size = 4096');
          await db.execute('PRAGMA kdf_iter = 256000');
        },
      );

      // Insert all data into new encrypted database
      await newDb.transaction((txn) async {
        for (final note in notes) {
          await txn.insert('notes', note);
        }
        for (final event in events) {
          await txn.insert('calendar_events', event);
        }
        for (final calc in calcHistory) {
          await txn.insert('calculator_history', calc);
        }
        for (final habit in habits) {
          await txn.insert('habits', habit);
        }
        for (final log in habitLogs) {
          await txn.insert('habit_logs', log);
        }
        for (final setting in settings) {
          await txn.insert('settings', setting);
        }
      });

      await newDb.close();
    } catch (e) {
      // If migration fails, clean up and rethrow
      await _secureStorage.delete(key: _migrationDoneKey);
      rethrow;
    }

    // Mark migration as complete
    await _secureStorage.write(key: _migrationDoneKey, value: 'true');
  }

  Future<String> _getOrCreateEncryptionKey() async {
    String? key = await _secureStorage.read(key: _encryptionKeyKey);
    if (key == null) {
      // Generate a new 256-bit key (32 bytes = 64 hex chars)
      final random = math.Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      key = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await _secureStorage.write(key: _encryptionKeyKey, value: key);
    }
    return key;
  }

  Future<void> _onCreate(sqlcipher.Database db, int version) async {
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
  }

  Future<void> _onUpgrade(sqlcipher.Database db, int oldVersion, int newVersion) async {
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
      final count = sqlcipher.Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM habits'));
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
    if (oldVersion < 5) {
      // Version 5 is the SQLCipher migration - handled in _migrateToEncrypted
      // No additional schema changes needed
    }
  }

  /// Clears the encryption key (for testing or user logout)
  Future<void> clearEncryptionKey() async {
    await _secureStorage.delete(key: _encryptionKeyKey);
    await _secureStorage.delete(key: _migrationDoneKey);
    _db = null;
  }
}