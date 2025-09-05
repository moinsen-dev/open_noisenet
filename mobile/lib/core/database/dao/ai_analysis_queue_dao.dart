import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/ai_analysis_queue.dart';

class AiAnalysisQueueDao {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  /// Insert a new analysis queue item
  Future<int> insert(AiAnalysisQueue queueItem) async {
    final db = await _databaseHelper.database;
    return await db.insert(
      DatabaseHelper.tableAiAnalysisQueue,
      queueItem.toMap(),
    );
  }

  /// Insert multiple queue items in a batch
  Future<void> insertBatch(List<AiAnalysisQueue> queueItems) async {
    if (queueItems.isEmpty) return;
    
    final db = await _databaseHelper.database;
    final batch = db.batch();
    
    for (final queueItem in queueItems) {
      batch.insert(
        DatabaseHelper.tableAiAnalysisQueue,
        queueItem.toMap(),
      );
    }
    
    await batch.commit(noResult: true);
  }

  /// Get queue item by ID
  Future<AiAnalysisQueue?> getById(int id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableAiAnalysisQueue,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return AiAnalysisQueue.fromMap(maps.first);
  }

  /// Get queue items by recording ID
  Future<List<AiAnalysisQueue>> getByRecordingId(String recordingId) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableAiAnalysisQueue,
      where: 'recording_id = ?',
      whereArgs: [recordingId],
      orderBy: 'id ASC',
    );
    
    return maps.map((map) => AiAnalysisQueue.fromMap(map)).toList();
  }

  /// Get queue items by status
  Future<List<AiAnalysisQueue>> getByStatus(AnalysisStatus status, {int? limit}) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableAiAnalysisQueue,
      where: 'status = ?',
      whereArgs: [status.name],
      orderBy: 'id ASC', // Process oldest first
      limit: limit,
    );
    
    return maps.map((map) => AiAnalysisQueue.fromMap(map)).toList();
  }

  /// Get pending queue items
  Future<List<AiAnalysisQueue>> getPending({int? limit}) async {
    return await getByStatus(AnalysisStatus.pending, limit: limit);
  }

  /// Get processing queue items
  Future<List<AiAnalysisQueue>> getProcessing({int? limit}) async {
    return await getByStatus(AnalysisStatus.processing, limit: limit);
  }

  /// Get completed queue items
  Future<List<AiAnalysisQueue>> getCompleted({int? limit}) async {
    return await getByStatus(AnalysisStatus.completed, limit: limit);
  }

  /// Get failed queue items
  Future<List<AiAnalysisQueue>> getFailed({int? limit}) async {
    return await getByStatus(AnalysisStatus.failed, limit: limit);
  }

  /// Get queue items by analysis type
  Future<List<AiAnalysisQueue>> getByAnalysisType(AnalysisType analysisType, {int? limit}) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableAiAnalysisQueue,
      where: 'analysis_type = ?',
      whereArgs: [analysisType.name],
      orderBy: 'id ASC',
      limit: limit,
    );
    
    return maps.map((map) => AiAnalysisQueue.fromMap(map)).toList();
  }

  /// Get next item to process
  Future<AiAnalysisQueue?> getNextToProcess() async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableAiAnalysisQueue,
      where: 'status = ?',
      whereArgs: [AnalysisStatus.pending.name],
      orderBy: 'id ASC',
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return AiAnalysisQueue.fromMap(maps.first);
  }

  /// Get all queue items
  Future<List<AiAnalysisQueue>> getAll({
    int? limit,
    String orderBy = 'id DESC',
  }) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableAiAnalysisQueue,
      orderBy: orderBy,
      limit: limit,
    );
    
    return maps.map((map) => AiAnalysisQueue.fromMap(map)).toList();
  }

  /// Update queue item
  Future<int> update(AiAnalysisQueue queueItem) async {
    final db = await _databaseHelper.database;
    return await db.update(
      DatabaseHelper.tableAiAnalysisQueue,
      queueItem.toMap(),
      where: 'id = ?',
      whereArgs: [queueItem.id],
    );
  }

  /// Update status
  Future<int> updateStatus(int id, AnalysisStatus status, {String? errorMessage}) async {
    final db = await _databaseHelper.database;
    final updateData = <String, dynamic>{
      'status': status.name,
    };
    
    if (status == AnalysisStatus.completed || status == AnalysisStatus.failed) {
      updateData['processed_at'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }
    
    if (errorMessage != null) {
      updateData['error_message'] = errorMessage;
    }
    
    return await db.update(
      DatabaseHelper.tableAiAnalysisQueue,
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark as processing
  Future<int> markAsProcessing(int id) async {
    return await updateStatus(id, AnalysisStatus.processing);
  }

  /// Mark as completed
  Future<int> markAsCompleted(int id, String result, {double? confidenceScore}) async {
    final db = await _databaseHelper.database;
    final updateData = <String, dynamic>{
      'status': AnalysisStatus.completed.name,
      'result': result,
      'processed_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
    
    if (confidenceScore != null) {
      updateData['confidence_score'] = confidenceScore;
    }
    
    return await db.update(
      DatabaseHelper.tableAiAnalysisQueue,
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark as failed
  Future<int> markAsFailed(int id, String errorMessage) async {
    return await updateStatus(id, AnalysisStatus.failed, errorMessage: errorMessage);
  }

  /// Delete queue item by ID
  Future<int> deleteById(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      DatabaseHelper.tableAiAnalysisQueue,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete queue items by recording ID
  Future<int> deleteByRecordingId(String recordingId) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      DatabaseHelper.tableAiAnalysisQueue,
      where: 'recording_id = ?',
      whereArgs: [recordingId],
    );
  }

  /// Delete completed items older than specified days
  Future<int> deleteCompletedOlderThanDays(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final cutoffTimestamp = cutoff.millisecondsSinceEpoch ~/ 1000;
    
    final db = await _databaseHelper.database;
    return await db.delete(
      DatabaseHelper.tableAiAnalysisQueue,
      where: 'status = ? AND processed_at < ?',
      whereArgs: [AnalysisStatus.completed.name, cutoffTimestamp],
    );
  }

  /// Delete failed items older than specified days
  Future<int> deleteFailedOlderThanDays(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final cutoffTimestamp = cutoff.millisecondsSinceEpoch ~/ 1000;
    
    final db = await _databaseHelper.database;
    return await db.delete(
      DatabaseHelper.tableAiAnalysisQueue,
      where: 'status = ? AND processed_at < ?',
      whereArgs: [AnalysisStatus.failed.name, cutoffTimestamp],
    );
  }

  /// Get count of all queue items
  Future<int> count() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableAiAnalysisQueue}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get count by status
  Future<int> countByStatus(AnalysisStatus status) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableAiAnalysisQueue} WHERE status = ?',
      [status.name],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get count of pending items
  Future<int> countPending() async {
    return await countByStatus(AnalysisStatus.pending);
  }

  /// Get count of processing items
  Future<int> countProcessing() async {
    return await countByStatus(AnalysisStatus.processing);
  }

  /// Get count of completed items
  Future<int> countCompleted() async {
    return await countByStatus(AnalysisStatus.completed);
  }

  /// Get count of failed items
  Future<int> countFailed() async {
    return await countByStatus(AnalysisStatus.failed);
  }

  /// Delete all queue items
  Future<int> deleteAll() async {
    final db = await _databaseHelper.database;
    return await db.delete(DatabaseHelper.tableAiAnalysisQueue);
  }

  /// Check if queue item exists
  Future<bool> exists(int id) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      DatabaseHelper.tableAiAnalysisQueue,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Check if recording has pending analysis
  Future<bool> hasPendingAnalysis(String recordingId, AnalysisType analysisType) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      DatabaseHelper.tableAiAnalysisQueue,
      columns: ['id'],
      where: 'recording_id = ? AND analysis_type = ? AND status = ?',
      whereArgs: [recordingId, analysisType.name, AnalysisStatus.pending.name],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Get queue statistics
  Future<Map<String, dynamic>> getQueueStats() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_items,
        SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_count,
        SUM(CASE WHEN status = 'processing' THEN 1 ELSE 0 END) as processing_count,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_count,
        SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_count,
        AVG(confidence_score) as avg_confidence
      FROM ${DatabaseHelper.tableAiAnalysisQueue}
    ''');
    
    if (result.isEmpty) {
      return {
        'total_items': 0,
        'pending_count': 0,
        'processing_count': 0,
        'completed_count': 0,
        'failed_count': 0,
        'avg_confidence': null,
      };
    }
    
    return result.first;
  }

  /// Reset processing items to pending (for crash recovery)
  Future<int> resetProcessingToPending() async {
    final db = await _databaseHelper.database;
    return await db.update(
      DatabaseHelper.tableAiAnalysisQueue,
      {'status': AnalysisStatus.pending.name},
      where: 'status = ?',
      whereArgs: [AnalysisStatus.processing.name],
    );
  }
}