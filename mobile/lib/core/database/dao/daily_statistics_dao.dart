import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/daily_statistics.dart';

class DailyStatisticsDao {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  /// Insert or replace daily statistics
  Future<int> insertOrReplace(DailyStatistics statistics) async {
    final db = await _databaseHelper.database;
    return await db.insert(
      DatabaseHelper.tableDailyStatistics,
      statistics.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple statistics in a batch
  Future<void> insertBatch(List<DailyStatistics> statisticsList) async {
    if (statisticsList.isEmpty) return;
    
    final db = await _databaseHelper.database;
    final batch = db.batch();
    
    for (final statistics in statisticsList) {
      batch.insert(
        DatabaseHelper.tableDailyStatistics,
        statistics.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  /// Get statistics by date
  Future<DailyStatistics?> getByDate(String date) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableDailyStatistics,
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return DailyStatistics.fromMap(maps.first);
  }

  /// Get statistics for a specific day
  Future<DailyStatistics?> getByDay(DateTime day) async {
    final dateString = '${day.year.toString().padLeft(4, '0')}-'
                     '${day.month.toString().padLeft(2, '0')}-'
                     '${day.day.toString().padLeft(2, '0')}';
    return await getByDate(dateString);
  }

  /// Get today's statistics
  Future<DailyStatistics?> getToday() async {
    return await getByDay(DateTime.now());
  }

  /// Get statistics for a date range
  Future<List<DailyStatistics>> getByDateRange({
    required String startDate,
    required String endDate,
    int? limit,
    String orderBy = 'date ASC',
  }) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableDailyStatistics,
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: orderBy,
      limit: limit,
    );
    
    return maps.map((map) => DailyStatistics.fromMap(map)).toList();
  }

  /// Get statistics for the last N days
  Future<List<DailyStatistics>> getLastNDays(int days) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days - 1));
    
    final endDateString = '${endDate.year.toString().padLeft(4, '0')}-'
                         '${endDate.month.toString().padLeft(2, '0')}-'
                         '${endDate.day.toString().padLeft(2, '0')}';
    final startDateString = '${startDate.year.toString().padLeft(4, '0')}-'
                          '${startDate.month.toString().padLeft(2, '0')}-'
                          '${startDate.day.toString().padLeft(2, '0')}';
    
    return await getByDateRange(
      startDate: startDateString,
      endDate: endDateString,
    );
  }

  /// Get statistics for the current week
  Future<List<DailyStatistics>> getCurrentWeek() async {
    return await getLastNDays(7);
  }

  /// Get statistics for the current month
  Future<List<DailyStatistics>> getCurrentMonth() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    final startDateString = '${startOfMonth.year.toString().padLeft(4, '0')}-'
                          '${startOfMonth.month.toString().padLeft(2, '0')}-01';
    final endDateString = '${now.year.toString().padLeft(4, '0')}-'
                         '${now.month.toString().padLeft(2, '0')}-'
                         '${now.day.toString().padLeft(2, '0')}';
    
    return await getByDateRange(
      startDate: startDateString,
      endDate: endDateString,
    );
  }

  /// Get recent statistics
  Future<List<DailyStatistics>> getRecent({
    int? limit = 30,
    String orderBy = 'date DESC',
  }) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableDailyStatistics,
      orderBy: orderBy,
      limit: limit,
    );
    
    return maps.map((map) => DailyStatistics.fromMap(map)).toList();
  }

  /// Find the loudest day in a date range
  Future<DailyStatistics?> getLoudestDay({
    String? startDate,
    String? endDate,
  }) async {
    final db = await _databaseHelper.database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (startDate != null && endDate != null) {
      whereClause = 'WHERE date >= ? AND date <= ?';
      whereArgs = [startDate, endDate];
    }
    
    final maps = await db.query(
      DatabaseHelper.tableDailyStatistics,
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'avg_leq DESC',
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return DailyStatistics.fromMap(maps.first);
  }

  /// Find the quietest day in a date range
  Future<DailyStatistics?> getQuietestDay({
    String? startDate,
    String? endDate,
  }) async {
    final db = await _databaseHelper.database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (startDate != null && endDate != null) {
      whereClause = 'WHERE date >= ? AND date <= ?';
      whereArgs = [startDate, endDate];
    }
    
    final maps = await db.query(
      DatabaseHelper.tableDailyStatistics,
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'avg_leq ASC',
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return DailyStatistics.fromMap(maps.first);
  }

  /// Get weekly pattern (average for each day of week)
  Future<List<Map<String, dynamic>>> getWeeklyPattern({
    int? weeksPeriod,
  }) async {
    // SQLite doesn't have direct day-of-week function, so we'll calculate it in Dart
    final statistics = await getRecent(limit: weeksPeriod != null ? weeksPeriod * 7 : null);
    final weeklyData = <int, List<double>>{};
    
    for (final stat in statistics) {
      final weekday = stat.dateTime.weekday; // 1=Monday, 7=Sunday
      weeklyData.putIfAbsent(weekday, () => []);
      weeklyData[weekday]!.add(stat.avgLeq);
    }
    
    final result = <Map<String, dynamic>>[];
    for (int weekday = 1; weekday <= 7; weekday++) {
      final values = weeklyData[weekday] ?? [];
      if (values.isNotEmpty) {
        final avg = values.reduce((a, b) => a + b) / values.length;
        result.add({
          'weekday': weekday,
          'avg_leq': avg,
          'count': values.length,
        });
      }
    }
    
    return result;
  }

  /// Update statistics
  Future<int> update(DailyStatistics statistics) async {
    final db = await _databaseHelper.database;
    return await db.update(
      DatabaseHelper.tableDailyStatistics,
      statistics.toMap(),
      where: 'id = ?',
      whereArgs: [statistics.id],
    );
  }

  /// Delete statistics by date
  Future<int> deleteByDate(String date) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      DatabaseHelper.tableDailyStatistics,
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  /// Delete statistics older than specified date
  Future<int> deleteOlderThan(String date) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      DatabaseHelper.tableDailyStatistics,
      where: 'date < ?',
      whereArgs: [date],
    );
  }

  /// Delete statistics older than specified days
  Future<int> deleteOlderThanDays(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final cutoffString = '${cutoff.year.toString().padLeft(4, '0')}-'
                        '${cutoff.month.toString().padLeft(2, '0')}-'
                        '${cutoff.day.toString().padLeft(2, '0')}';
    return await deleteOlderThan(cutoffString);
  }

  /// Get count of all statistics
  Future<int> count() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableDailyStatistics}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Delete all statistics
  Future<int> deleteAll() async {
    final db = await _databaseHelper.database;
    return await db.delete(DatabaseHelper.tableDailyStatistics);
  }

  /// Check if statistics exist for a specific date
  Future<bool> existsForDate(String date) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      DatabaseHelper.tableDailyStatistics,
      columns: ['id'],
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Get statistics above threshold
  Future<List<DailyStatistics>> getAboveThreshold({
    required double thresholdDb,
    int? limit,
  }) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableDailyStatistics,
      where: 'avg_leq >= ?',
      whereArgs: [thresholdDb],
      orderBy: 'date DESC',
      limit: limit,
    );
    
    return maps.map((map) => DailyStatistics.fromMap(map)).toList();
  }

  /// Calculate aggregate statistics for a period
  Future<Map<String, double?>> getAggregateStats({
    String? startDate,
    String? endDate,
  }) async {
    final db = await _databaseHelper.database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (startDate != null && endDate != null) {
      whereClause = 'WHERE date >= ? AND date <= ?';
      whereArgs = [startDate, endDate];
    }
    
    final result = await db.rawQuery('''
      SELECT 
        AVG(avg_leq) as avg_leq,
        MAX(max_leq) as max_leq,
        MIN(min_leq) as min_leq,
        SUM(total_exceedances) as total_exceedances,
        SUM(total_samples) as total_samples,
        COUNT(*) as days_count
      FROM ${DatabaseHelper.tableDailyStatistics}
      $whereClause
    ''', whereArgs);
    
    if (result.isEmpty) {
      return {
        'avg_leq': null,
        'max_leq': null,
        'min_leq': null,
        'total_exceedances': 0,
        'total_samples': 0,
        'days_count': 0,
      };
    }
    
    final row = result.first;
    return {
      'avg_leq': row['avg_leq'] as double?,
      'max_leq': row['max_leq'] as double?,
      'min_leq': row['min_leq'] as double?,
      'total_exceedances': (row['total_exceedances'] as int?)?.toDouble() ?? 0,
      'total_samples': (row['total_samples'] as int?)?.toDouble() ?? 0,
      'days_count': (row['days_count'] as int?)?.toDouble() ?? 0,
    };
  }
}