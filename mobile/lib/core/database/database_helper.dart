import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String _databaseName = 'noisenet.db';
  static const int _databaseVersion = 2;

  // Table names
  static const String tableNoiseMeasurements = 'noise_measurements';
  static const String tableNoiseEvents = 'noise_events';
  static const String tableHourlyStatistics = 'hourly_statistics';
  static const String tableDailyStatistics = 'daily_statistics';
  static const String tableAudioRecordings = 'audio_recordings';
  static const String tableAiAnalysisQueue = 'ai_analysis_queue';
  static const String tablePreferences = 'preferences';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create noise_measurements table
    await db.execute('''
      CREATE TABLE $tableNoiseMeasurements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        leq_db REAL NOT NULL,
        lmax_db REAL,
        lmin_db REAL,
        l10_db REAL,
        l50_db REAL,
        l90_db REAL,
        samples_count INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');

    // Create noise_events table
    await db.execute('''
      CREATE TABLE $tableNoiseEvents (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        timestamp_start INTEGER NOT NULL,
        timestamp_end INTEGER NOT NULL,
        leq_db REAL NOT NULL,
        lmax_db REAL,
        lmin_db REAL,
        rule_triggered TEXT,
        location_lat REAL,
        location_lng REAL,
        event_metadata TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        is_submitted INTEGER NOT NULL DEFAULT 0,
        retry_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    // Create hourly_statistics table
    await db.execute('''
      CREATE TABLE $tableHourlyStatistics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hour_timestamp INTEGER NOT NULL UNIQUE,
        avg_leq REAL NOT NULL,
        max_leq REAL NOT NULL,
        min_leq REAL NOT NULL,
        l10 REAL,
        l50 REAL,
        l90 REAL,
        exceedance_count INTEGER NOT NULL DEFAULT 0,
        total_samples INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create daily_statistics table
    await db.execute('''
      CREATE TABLE $tableDailyStatistics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        avg_leq REAL NOT NULL,
        max_leq REAL NOT NULL,
        min_leq REAL NOT NULL,
        peak_hour INTEGER,
        quiet_hour INTEGER,
        total_exceedances INTEGER NOT NULL DEFAULT 0,
        total_samples INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create audio_recordings table
    await db.execute('''
      CREATE TABLE $tableAudioRecordings (
        id TEXT PRIMARY KEY,
        event_id TEXT,
        timestamp_start INTEGER NOT NULL,
        timestamp_end INTEGER NOT NULL,
        duration_seconds INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        file_size INTEGER,
        sample_rate INTEGER,
        format TEXT NOT NULL DEFAULT 'wav',
        is_analyzed INTEGER NOT NULL DEFAULT 0,
        analysis_result TEXT,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        FOREIGN KEY (event_id) REFERENCES $tableNoiseEvents (id)
      )
    ''');

    // Create ai_analysis_queue table
    await db.execute('''
      CREATE TABLE $tableAiAnalysisQueue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recording_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        model_version TEXT,
        analysis_type TEXT NOT NULL,
        result TEXT,
        confidence_score REAL,
        processed_at INTEGER,
        error_message TEXT,
        FOREIGN KEY (recording_id) REFERENCES $tableAudioRecordings (id)
      )
    ''');

    // Create preferences table
    await db.execute('''
      CREATE TABLE $tablePreferences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL,
        data_type TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create indexes for performance
    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX idx_measurements_timestamp ON $tableNoiseMeasurements(timestamp)');
    await db.execute('CREATE INDEX idx_events_timestamp ON $tableNoiseEvents(timestamp_start)');
    await db.execute('CREATE INDEX idx_events_status ON $tableNoiseEvents(status)');
    await db.execute('CREATE INDEX idx_recordings_event ON $tableAudioRecordings(event_id)');
    await db.execute('CREATE INDEX idx_recordings_expires ON $tableAudioRecordings(expires_at)');
    await db.execute('CREATE INDEX idx_hourly_timestamp ON $tableHourlyStatistics(hour_timestamp)');
    await db.execute('CREATE INDEX idx_daily_date ON $tableDailyStatistics(date)');
    await db.execute('CREATE INDEX idx_preferences_key ON $tablePreferences(key)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database schema upgrades here
    if (oldVersion < 2) {
      // Add preferences table in version 2
      await db.execute('''
        CREATE TABLE $tablePreferences (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          key TEXT NOT NULL UNIQUE,
          value TEXT NOT NULL,
          data_type TEXT NOT NULL,
          description TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      
      // Add preferences index
      await db.execute('CREATE INDEX idx_preferences_key ON $tablePreferences(key)');
    }
    
    // Add future migrations here as needed
  }

  /// Close the database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Delete the database file (for testing/debugging)
  Future<void> deleteDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    await File(path).delete();
    _database = null;
  }

  /// Get database file size in bytes
  Future<int> getDatabaseSize() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  /// Vacuum the database to reclaim space
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  /// Execute raw SQL query (for debugging/admin purposes)
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }
}