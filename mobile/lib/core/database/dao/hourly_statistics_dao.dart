import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/hourly_statistics.dart';

class HourlyStatisticsDao {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  /// Insert or replace hourly statistics
  Future<int> insertOrReplace(HourlyStatistics statistics) async {
    final db = await _databaseHelper.database;
    return await db.insert(
      DatabaseHelper.tableHourlyStatistics,
      statistics.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple statistics in a batch
  Future<void> insertBatch(List<HourlyStatistics> statisticsList) async {
    if (statisticsList.isEmpty) return;
    
    final db = await _databaseHelper.database;
    final batch = db.batch();
    
    for (final statistics in statisticsList) {
      batch.insert(
        DatabaseHelper.tableHourlyStatistics,
        statistics.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  /// Get statistics by hour timestamp
  Future<HourlyStatistics?> getByHourTimestamp(int hourTimestamp) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableHourlyStatistics,
      where: 'hour_timestamp = ?',
      whereArgs: [hourTimestamp],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return HourlyStatistics.fromMap(maps.first);
  }

  /// Get statistics for a specific hour
  Future<HourlyStatistics?> getByHour(DateTime hour) async {
    final startOfHour = DateTime(hour.year, hour.month, hour.day, hour.hour);
    final hourTimestamp = startOfHour.millisecondsSinceEpoch ~/ 1000;
    return await getByHourTimestamp(hourTimestamp);
  }

  /// Get statistics for a time range
  Future<List<HourlyStatistics>> getByTimeRange({
    required int startTimestamp,
    required int endTimestamp,
    int? limit,
    String orderBy = 'hour_timestamp ASC',
  }) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableHourlyStatistics,
      where: 'hour_timestamp >= ? AND hour_timestamp <= ?',
      whereArgs: [startTimestamp, endTimestamp],
      orderBy: orderBy,
      limit: limit,
    );
    
    return maps.map((map) => HourlyStatistics.fromMap(map)).toList();
  }

  /// Get statistics for the last 24 hours
  Future<List<HourlyStatistics>> getLast24Hours() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));
    
    // Round to hour boundaries
    final endHour = DateTime(now.year, now.month, now.day, now.hour);
    final startHour = DateTime(yesterday.year, yesterday.month, yesterday.day, yesterday.hour);
    
    return await getByTimeRange(
      startTimestamp: startHour.millisecondsSinceEpoch ~/ 1000,
      endTimestamp: endHour.millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Get statistics for a specific day
  Future<List<HourlyStatistics>> getByDay(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return await getByTimeRange(
      startTimestamp: startOfDay.millisecondsSinceEpoch ~/ 1000,
      endTimestamp: endOfDay.millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Get statistics for the current week
  Future<List<HourlyStatistics>> getCurrentWeek() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekHour = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    return await getByTimeRange(
      startTimestamp: startOfWeekHour.millisecondsSinceEpoch ~/ 1000,
      endTimestamp: now.millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Get recent statistics
  Future<List<HourlyStatistics>> getRecent({
    int limit = 100,
    String orderBy = 'hour_timestamp DESC',
  }) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableHourlyStatistics,
      orderBy: orderBy,
      limit: limit,
    );
    
    return maps.map((map) => HourlyStatistics.fromMap(map)).toList();
  }

  /// Find the loudest hour in a time range
  Future<HourlyStatistics?> getLoudestHour({
    required int startTimestamp,
    required int endTimestamp,
  }) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableHourlyStatistics,
      where: 'hour_timestamp >= ? AND hour_timestamp <= ?',
      whereArgs: [startTimestamp, endTimestamp],
      orderBy: 'avg_leq DESC',
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return HourlyStatistics.fromMap(maps.first);
  }

  /// Find the quietest hour in a time range
  Future<HourlyStatistics?> getQuietestHour({
    required int startTimestamp,
    required int endTimestamp,
  }) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableHourlyStatistics,
      where: 'hour_timestamp >= ? AND hour_timestamp <= ?',
      whereArgs: [startTimestamp, endTimestamp],
      orderBy: 'avg_leq ASC',
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return HourlyStatistics.fromMap(maps.first);
  }

  /// Get daily pattern (average for each hour of day)
  Future<List<Map<String, dynamic>>> getDailyPattern({
    int? daysPeriod,
  }) async {
    final db = await _databaseHelper.database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (daysPeriod != null) {
      final cutoff = DateTime.now().subtract(Duration(days: daysPeriod));
      whereClause = 'WHERE hour_timestamp >= ?';
      whereArgs = [cutoff.millisecondsSinceEpoch ~/ 1000];
    }
    
    final result = await db.rawQuery('''
      SELECT 
        (hour_timestamp % 86400) / 3600 as hour_of_day,
        AVG(avg_leq) as avg_leq,
        AVG(max_leq) as avg_max,
        AVG(min_leq) as avg_min,
        COUNT(*) as count
      FROM ${DatabaseHelper.tableHourlyStatistics}
      $whereClause
      GROUP BY hour_of_day
      ORDER BY hour_of_day
    ''', whereArgs);
    
    return result;
  }

  /// Update statistics
  Future<int> update(HourlyStatistics statistics) async {
    final db = await _databaseHelper.database;
    return await db.update(
      DatabaseHelper.tableHourlyStatistics,
      statistics.toMap(),
      where: 'id = ?',
      whereArgs: [statistics.id],
    );
  }

  /// Delete statistics by hour timestamp
  Future<int> deleteByHourTimestamp(int hourTimestamp) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      DatabaseHelper.tableHourlyStatistics,
      where: 'hour_timestamp = ?',
      whereArgs: [hourTimestamp],
    );
  }

  /// Delete statistics older than specified timestamp
  Future<int> deleteOlderThan(int timestamp) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      DatabaseHelper.tableHourlyStatistics,
      where: 'hour_timestamp < ?',
      whereArgs: [timestamp],
    );
  }

  /// Delete statistics older than specified days
  Future<int> deleteOlderThanDays(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return await deleteOlderThan(cutoff.millisecondsSinceEpoch ~/ 1000);
  }

  /// Get count of all statistics
  Future<int> count() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableHourlyStatistics}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Delete all statistics
  Future<int> deleteAll() async {
    final db = await _databaseHelper.database;
    return await db.delete(DatabaseHelper.tableHourlyStatistics);
  }

  /// Check if statistics exist for a specific hour
  Future<bool> existsForHour(int hourTimestamp) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      DatabaseHelper.tableHourlyStatistics,
      columns: ['id'],
      where: 'hour_timestamp = ?',
      whereArgs: [hourTimestamp],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Get statistics above threshold
  Future<List<HourlyStatistics>> getAboveThreshold({
    required double thresholdDb,
    int? limit,
  }) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableHourlyStatistics,
      where: 'avg_leq >= ?',
      whereArgs: [thresholdDb],
      orderBy: 'hour_timestamp DESC',
      limit: limit,
    );
    
    return maps.map((map) => HourlyStatistics.fromMap(map)).toList();
  }

  /// Calculate aggregate statistics for a period
  Future<Map<String, double?>> getAggregateStats({
    required int startTimestamp,
    required int endTimestamp,
  }) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        AVG(avg_leq) as avg_leq,
        MAX(max_leq) as max_leq,
        MIN(min_leq) as min_leq,
        SUM(exceedance_count) as total_exceedances,
        SUM(total_samples) as total_samples,
        COUNT(*) as hours_count
      FROM ${DatabaseHelper.tableHourlyStatistics}
      WHERE hour_timestamp >= ? AND hour_timestamp <= ?
    ''', [startTimestamp, endTimestamp]);
    
    if (result.isEmpty) {
      return {
        'avg_leq': null,
        'max_leq': null,
        'min_leq': null,
        'total_exceedances': 0,
        'total_samples': 0,
        'hours_count': 0,
      };
    }
    
    final row = result.first;
    return {
      'avg_leq': row['avg_leq'] as double?,
      'max_leq': row['max_leq'] as double?,
      'min_leq': row['min_leq'] as double?,
      'total_exceedances': (row['total_exceedances'] as int?)?.toDouble() ?? 0,
      'total_samples': (row['total_samples'] as int?)?.toDouble() ?? 0,
      'hours_count': (row['hours_count'] as int?)?.toDouble() ?? 0,
    };
  }
}