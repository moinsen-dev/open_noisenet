import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/audio_recording.dart';

class AudioRecordingDao {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  /// Insert a new audio recording
  Future<int> insert(AudioRecording recording) async {
    final db = await _databaseHelper.database;
    return await db.insert(
      DatabaseHelper.tableAudioRecordings,
      recording.toMap(),
    );
  }

  /// Insert multiple recordings in a batch
  Future<void> insertBatch(List<AudioRecording> recordings) async {
    if (recordings.isEmpty) return;
    
    final db = await _databaseHelper.database;
    final batch = db.batch();
    
    for (final recording in recordings) {
      batch.insert(
        DatabaseHelper.tableAudioRecordings,
        recording.toMap(),
      );
    }
    
    await batch.commit(noResult: true);
  }

  /// Get recording by ID
  Future<AudioRecording?> getById(String id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableAudioRecordings,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return AudioRecording.fromMap(maps.first);
  }

  /// Get recordings for a specific event
  Future<List<AudioRecording>> getByEventId(String eventId) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableAudioRecordings,
      where: 'event_id = ?',
      whereArgs: [eventId],
      orderBy: 'timestamp_start ASC',
    );
    
    return maps.map((map) => AudioRecording.fromMap(map)).toList();
  }

  /// Get recordings for a time range
  Future<List<AudioRecording>> getByTimeRange({
    required int startTimestamp,
    required int endTimestamp,
    int? limit,
    String orderBy = 'timestamp_start ASC',
  }) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableAudioRecordings,
      where: 'timestamp_start >= ? AND timestamp_start <= ?',
      whereArgs: [startTimestamp, endTimestamp],
      orderBy: orderBy,
      limit: limit,
    );
    
    return maps.map((map) => AudioRecording.fromMap(map)).toList();
  }

  /// Get recent recordings
  Future<List<AudioRecording>> getRecent({
    int limit = 50,
    String orderBy = 'timestamp_start DESC',
  }) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableAudioRecordings,
      orderBy: orderBy,
      limit: limit,
    );
    
    return maps.map((map) => AudioRecording.fromMap(map)).toList();
  }

  /// Get recordings that haven't been analyzed
  Future<List<AudioRecording>> getUnanalyzed({
    int? limit,
  }) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableAudioRecordings,
      where: 'is_analyzed = 0',
      orderBy: 'created_at ASC', // Process older recordings first
      limit: limit,
    );
    
    return maps.map((map) => AudioRecording.fromMap(map)).toList();
  }

  /// Get recordings that have been analyzed
  Future<List<AudioRecording>> getAnalyzed({
    int? limit,
  }) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableAudioRecordings,
      where: 'is_analyzed = 1',
      orderBy: 'timestamp_start DESC',
      limit: limit,
    );
    
    return maps.map((map) => AudioRecording.fromMap(map)).toList();
  }

  /// Get expired recordings
  Future<List<AudioRecording>> getExpired() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableAudioRecordings,
      where: 'expires_at <= ?',
      whereArgs: [now],
      orderBy: 'expires_at ASC',
    );
    
    return maps.map((map) => AudioRecording.fromMap(map)).toList();
  }

  /// Get recordings by format
  Future<List<AudioRecording>> getByFormat(String format) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableAudioRecordings,
      where: 'format = ?',
      whereArgs: [format],
      orderBy: 'timestamp_start DESC',
    );
    
    return maps.map((map) => AudioRecording.fromMap(map)).toList();
  }

  /// Update recording
  Future<int> update(AudioRecording recording) async {
    final db = await _databaseHelper.database;
    return await db.update(
      DatabaseHelper.tableAudioRecordings,
      recording.toMap(),
      where: 'id = ?',
      whereArgs: [recording.id],
    );
  }

  /// Mark recording as analyzed
  Future<int> markAsAnalyzed(String id, String analysisResult) async {
    final db = await _databaseHelper.database;
    return await db.update(
      DatabaseHelper.tableAudioRecordings,
      {
        'is_analyzed': 1,
        'analysis_result': analysisResult,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update file size
  Future<int> updateFileSize(String id, int fileSize) async {
    final db = await _databaseHelper.database;
    return await db.update(
      DatabaseHelper.tableAudioRecordings,
      {'file_size': fileSize},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete recording by ID
  Future<int> deleteById(String id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      DatabaseHelper.tableAudioRecordings,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete recordings for a specific event
  Future<int> deleteByEventId(String eventId) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      DatabaseHelper.tableAudioRecordings,
      where: 'event_id = ?',
      whereArgs: [eventId],
    );
  }

  /// Delete expired recordings
  Future<int> deleteExpired() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final db = await _databaseHelper.database;
    return await db.delete(
      DatabaseHelper.tableAudioRecordings,
      where: 'expires_at <= ?',
      whereArgs: [now],
    );
  }

  /// Delete recordings older than specified timestamp
  Future<int> deleteOlderThan(int timestamp) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      DatabaseHelper.tableAudioRecordings,
      where: 'timestamp_start < ?',
      whereArgs: [timestamp],
    );
  }

  /// Delete recordings older than specified days
  Future<int> deleteOlderThanDays(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return await deleteOlderThan(cutoff.millisecondsSinceEpoch ~/ 1000);
  }

  /// Get count of all recordings
  Future<int> count() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableAudioRecordings}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get count of analyzed recordings
  Future<int> countAnalyzed() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableAudioRecordings} WHERE is_analyzed = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get count of unanalyzed recordings
  Future<int> countUnanalyzed() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableAudioRecordings} WHERE is_analyzed = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get total file size of all recordings
  Future<int> getTotalFileSize() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(file_size) as total FROM ${DatabaseHelper.tableAudioRecordings} WHERE file_size IS NOT NULL',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Delete all recordings
  Future<int> deleteAll() async {
    final db = await _databaseHelper.database;
    return await db.delete(DatabaseHelper.tableAudioRecordings);
  }

  /// Check if recording exists
  Future<bool> exists(String id) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      DatabaseHelper.tableAudioRecordings,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Get storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_recordings,
        SUM(CASE WHEN is_analyzed = 1 THEN 1 ELSE 0 END) as analyzed_count,
        SUM(CASE WHEN is_analyzed = 0 THEN 1 ELSE 0 END) as unanalyzed_count,
        SUM(file_size) as total_size,
        AVG(duration_seconds) as avg_duration,
        MIN(timestamp_start) as oldest_timestamp,
        MAX(timestamp_start) as newest_timestamp
      FROM ${DatabaseHelper.tableAudioRecordings}
    ''');
    
    if (result.isEmpty) {
      return {
        'total_recordings': 0,
        'analyzed_count': 0,
        'unanalyzed_count': 0,
        'total_size': 0,
        'avg_duration': 0,
        'oldest_timestamp': null,
        'newest_timestamp': null,
      };
    }
    
    return result.first;
  }

  /// Get recordings by analysis status and time range
  Future<List<AudioRecording>> getByAnalysisStatus({
    required bool isAnalyzed,
    int? startTimestamp,
    int? endTimestamp,
    int? limit,
  }) async {
    final db = await _databaseHelper.database;
    
    String whereClause = 'is_analyzed = ?';
    List<dynamic> whereArgs = [isAnalyzed ? 1 : 0];
    
    if (startTimestamp != null && endTimestamp != null) {
      whereClause += ' AND timestamp_start >= ? AND timestamp_start <= ?';
      whereArgs.addAll([startTimestamp, endTimestamp]);
    }
    
    final maps = await db.query(
      DatabaseHelper.tableAudioRecordings,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp_start DESC',
      limit: limit,
    );
    
    return maps.map((map) => AudioRecording.fromMap(map)).toList();
  }
}