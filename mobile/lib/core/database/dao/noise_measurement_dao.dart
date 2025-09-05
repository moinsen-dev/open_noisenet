import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/noise_measurement.dart';

class NoiseMeasurementDao {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  /// Insert a new measurement
  Future<int> insert(NoiseMeasurement measurement) async {
    final db = await _databaseHelper.database;
    return await db.insert(
      DatabaseHelper.tableNoiseMeasurements,
      measurement.toMap(),
    );
  }

  /// Insert multiple measurements in a batch
  Future<void> insertBatch(List<NoiseMeasurement> measurements) async {
    if (measurements.isEmpty) return;
    
    final db = await _databaseHelper.database;
    final batch = db.batch();
    
    for (final measurement in measurements) {
      batch.insert(
        DatabaseHelper.tableNoiseMeasurements,
        measurement.toMap(),
      );
    }
    
    await batch.commit(noResult: true);
  }

  /// Get measurement by ID
  Future<NoiseMeasurement?> getById(int id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableNoiseMeasurements,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return NoiseMeasurement.fromMap(maps.first);
  }

  /// Get measurements for a specific time range
  Future<List<NoiseMeasurement>> getByTimeRange({
    required int startTimestamp,
    required int endTimestamp,
    int? limit,
    String orderBy = 'timestamp ASC',
  }) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableNoiseMeasurements,
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [startTimestamp, endTimestamp],
      orderBy: orderBy,
      limit: limit,
    );
    
    return maps.map((map) => NoiseMeasurement.fromMap(map)).toList();
  }

  /// Get recent measurements (last N entries)
  Future<List<NoiseMeasurement>> getRecent({
    int limit = 100,
    String orderBy = 'timestamp DESC',
  }) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableNoiseMeasurements,
      orderBy: orderBy,
      limit: limit,
    );
    
    return maps.map((map) => NoiseMeasurement.fromMap(map)).toList();
  }

  /// Get measurements for the last 24 hours
  Future<List<NoiseMeasurement>> getLast24Hours() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));
    
    return await getByTimeRange(
      startTimestamp: yesterday.millisecondsSinceEpoch ~/ 1000,
      endTimestamp: now.millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Get measurements for a specific hour
  Future<List<NoiseMeasurement>> getByHour(DateTime hour) async {
    final startOfHour = DateTime(hour.year, hour.month, hour.day, hour.hour);
    final endOfHour = startOfHour.add(const Duration(hours: 1));
    
    return await getByTimeRange(
      startTimestamp: startOfHour.millisecondsSinceEpoch ~/ 1000,
      endTimestamp: endOfHour.millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Get measurements for a specific day
  Future<List<NoiseMeasurement>> getByDay(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return await getByTimeRange(
      startTimestamp: startOfDay.millisecondsSinceEpoch ~/ 1000,
      endTimestamp: endOfDay.millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Calculate aggregated statistics for a time range
  Future<Map<String, double?>> getAggregatedStats({
    required int startTimestamp,
    required int endTimestamp,
  }) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        AVG(leq_db) as avg_leq,
        MAX(lmax_db) as max_leq,
        MIN(lmin_db) as min_leq,
        AVG(l10_db) as avg_l10,
        AVG(l50_db) as avg_l50,
        AVG(l90_db) as avg_l90,
        COUNT(*) as count
      FROM ${DatabaseHelper.tableNoiseMeasurements}
      WHERE timestamp >= ? AND timestamp <= ?
    ''', [startTimestamp, endTimestamp]);
    
    if (result.isEmpty) {
      return {
        'avg_leq': null,
        'max_leq': null,
        'min_leq': null,
        'avg_l10': null,
        'avg_l50': null,
        'avg_l90': null,
        'count': 0,
      };
    }
    
    final row = result.first;
    return {
      'avg_leq': row['avg_leq'] as double?,
      'max_leq': row['max_leq'] as double?,
      'min_leq': row['min_leq'] as double?,
      'avg_l10': row['avg_l10'] as double?,
      'avg_l50': row['avg_l50'] as double?,
      'avg_l90': row['avg_l90'] as double?,
      'count': (row['count'] as int?)?.toDouble(),
    };
  }

  /// Update a measurement
  Future<int> update(NoiseMeasurement measurement) async {
    final db = await _databaseHelper.database;
    return await db.update(
      DatabaseHelper.tableNoiseMeasurements,
      measurement.toMap(),
      where: 'id = ?',
      whereArgs: [measurement.id],
    );
  }

  /// Delete measurement by ID
  Future<int> deleteById(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      DatabaseHelper.tableNoiseMeasurements,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete measurements older than specified timestamp
  Future<int> deleteOlderThan(int timestamp) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      DatabaseHelper.tableNoiseMeasurements,
      where: 'timestamp < ?',
      whereArgs: [timestamp],
    );
  }

  /// Delete measurements older than 24 hours
  Future<int> deleteOlderThan24Hours() async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return await deleteOlderThan(cutoff.millisecondsSinceEpoch ~/ 1000);
  }

  /// Get count of all measurements
  Future<int> count() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableNoiseMeasurements}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Delete all measurements
  Future<int> deleteAll() async {
    final db = await _databaseHelper.database;
    return await db.delete(DatabaseHelper.tableNoiseMeasurements);
  }

  /// Get the latest measurement
  Future<NoiseMeasurement?> getLatest() async {
    final measurements = await getRecent(limit: 1);
    return measurements.isEmpty ? null : measurements.first;
  }

  /// Check if a measurement exists for a specific timestamp
  Future<bool> existsForTimestamp(int timestamp) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      DatabaseHelper.tableNoiseMeasurements,
      columns: ['id'],
      where: 'timestamp = ?',
      whereArgs: [timestamp],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Get measurements with high noise levels above threshold
  Future<List<NoiseMeasurement>> getAboveThreshold({
    required double thresholdDb,
    int? limit,
  }) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableNoiseMeasurements,
      where: 'leq_db >= ?',
      whereArgs: [thresholdDb],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    
    return maps.map((map) => NoiseMeasurement.fromMap(map)).toList();
  }
}