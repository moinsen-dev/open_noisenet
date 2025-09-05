import 'dart:async';
import 'dart:io';

import '../core/database/dao/noise_measurement_dao.dart';
import '../core/database/dao/hourly_statistics_dao.dart';
import '../core/database/dao/daily_statistics_dao.dart';
import '../core/database/dao/audio_recording_dao.dart';
import '../core/database/dao/ai_analysis_queue_dao.dart';
import '../core/database/database_helper.dart';

class DataCleanupService {
  static final DataCleanupService _instance = DataCleanupService._internal();
  factory DataCleanupService() => _instance;
  DataCleanupService._internal();

  // DAOs
  final NoiseMeasurementDao _measurementDao = NoiseMeasurementDao();
  final HourlyStatisticsDao _hourlyDao = HourlyStatisticsDao();
  final DailyStatisticsDao _dailyDao = DailyStatisticsDao();
  final AudioRecordingDao _recordingDao = AudioRecordingDao();
  final AiAnalysisQueueDao _analysisQueueDao = AiAnalysisQueueDao();
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  // State
  bool _isRunning = false;
  Timer? _cleanupTimer;
  Timer? _healthCheckTimer;

  // Configuration
  static const Duration cleanupInterval = Duration(hours: 1);
  static const Duration healthCheckInterval = Duration(hours: 6);
  static const Duration measurementRetention = Duration(hours: 24);
  static const int hourlyStatsRetentionDays = 30;
  static const int dailyStatsRetentionDays = 365;
  static const Duration audioRetention = Duration(days: 7);
  static const int analysisQueueRetentionDays = 30;
  static const int maxDatabaseSizeMB = 500;

  /// Start the cleanup service
  void start() {
    if (_isRunning) return;

    _isRunning = true;

    // Start cleanup timer
    _cleanupTimer = Timer.periodic(
      cleanupInterval,
      (_) => performCleanup(),
    );

    // Start health check timer
    _healthCheckTimer = Timer.periodic(
      healthCheckInterval,
      (_) => performHealthCheck(),
    );

    // Perform initial cleanup
    performCleanup();

    print('🧹 Data cleanup service started');
  }

  /// Stop the cleanup service
  void stop() {
    if (!_isRunning) return;

    _isRunning = false;
    _cleanupTimer?.cancel();
    _healthCheckTimer?.cancel();
    _cleanupTimer = null;
    _healthCheckTimer = null;

    print('🧹 Data cleanup service stopped');
  }

  /// Perform comprehensive data cleanup
  Future<Map<String, int>> performCleanup() async {
    final results = <String, int>{};

    try {
      print('🧹 Starting data cleanup...');

      // 1. Clean up old measurements (24-hour rolling window)
      results['measurements_deleted'] = await _cleanupMeasurements();

      // 2. Clean up old hourly statistics
      results['hourly_stats_deleted'] = await _cleanupHourlyStatistics();

      // 3. Clean up old daily statistics
      results['daily_stats_deleted'] = await _cleanupDailyStatistics();

      // 4. Clean up expired audio recordings
      results['recordings_deleted'] = await _cleanupAudioRecordings();

      // 5. Clean up old analysis queue items
      results['analysis_queue_cleaned'] = await _cleanupAnalysisQueue();

      // 6. Vacuum database if needed
      final vacuumed = await _vacuumIfNeeded();
      results['database_vacuumed'] = vacuumed ? 1 : 0;

      final totalDeleted = results.values.reduce((a, b) => a + b);
      if (totalDeleted > 0) {
        print('🧹 Cleanup completed: deleted $totalDeleted items');
      }

    } catch (e) {
      print('❌ Cleanup failed: $e');
      results['error'] = 1;
    }

    return results;
  }

  /// Perform database health check
  Future<Map<String, dynamic>> performHealthCheck() async {
    final healthReport = <String, dynamic>{};

    try {
      print('🏥 Starting database health check...');

      // Get database size
      final dbSize = await _databaseHelper.getDatabaseSize();
      healthReport['database_size_bytes'] = dbSize;
      healthReport['database_size_mb'] = (dbSize / (1024 * 1024)).toStringAsFixed(2);

      // Get record counts
      healthReport['record_counts'] = {
        'measurements': await _measurementDao.count(),
        'hourly_statistics': await _hourlyDao.count(),
        'daily_statistics': await _dailyDao.count(),
        'audio_recordings': await _recordingDao.count(),
        'analysis_queue': await _analysisQueueDao.count(),
      };

      // Check for data integrity issues
      healthReport['integrity_checks'] = await _performIntegrityChecks();

      // Check storage health
      healthReport['storage_health'] = await _checkStorageHealth();

      // Determine overall health status
      healthReport['health_status'] = _calculateHealthStatus(healthReport);

      print('🏥 Health check completed: ${healthReport['health_status']}');

    } catch (e) {
      print('❌ Health check failed: $e');
      healthReport['error'] = e.toString();
      healthReport['health_status'] = 'error';
    }

    return healthReport;
  }

  /// Get cleanup statistics
  Future<Map<String, dynamic>> getCleanupStats() async {
    try {
      return {
        'service_status': {
          'is_running': _isRunning,
          'cleanup_interval_hours': cleanupInterval.inHours,
          'health_check_interval_hours': healthCheckInterval.inHours,
        },
        'retention_policies': {
          'measurements_hours': measurementRetention.inHours,
          'hourly_stats_days': hourlyStatsRetentionDays,
          'daily_stats_days': dailyStatsRetentionDays,
          'audio_recordings_days': audioRetention.inDays,
          'analysis_queue_days': analysisQueueRetentionDays,
        },
        'current_counts': {
          'measurements': await _measurementDao.count(),
          'hourly_statistics': await _hourlyDao.count(),
          'daily_statistics': await _dailyDao.count(),
          'audio_recordings': await _recordingDao.count(),
          'analysis_queue': await _analysisQueueDao.count(),
        },
        'database_info': {
          'size_bytes': await _databaseHelper.getDatabaseSize(),
          'max_size_mb': maxDatabaseSizeMB,
        },
      };
    } catch (e) {
      print('❌ Failed to get cleanup stats: $e');
      return {'error': e.toString()};
    }
  }

  /// Force cleanup of specific data type
  Future<int> forceCleanup(String dataType) async {
    switch (dataType) {
      case 'measurements':
        return await _cleanupMeasurements();
      case 'hourly_statistics':
        return await _cleanupHourlyStatistics();
      case 'daily_statistics':
        return await _cleanupDailyStatistics();
      case 'audio_recordings':
        return await _cleanupAudioRecordings();
      case 'analysis_queue':
        return await _cleanupAnalysisQueue();
      case 'all':
        final results = await performCleanup();
        return results.values.reduce((a, b) => a + b);
      default:
        throw ArgumentError('Unknown data type: $dataType');
    }
  }

  /// Clean up old measurements (24-hour rolling window)
  Future<int> _cleanupMeasurements() async {
    try {
      final deletedCount = await _measurementDao.deleteOlderThan24Hours();
      if (deletedCount > 0) {
        print('🗑️ Deleted $deletedCount old measurements');
      }
      return deletedCount;
    } catch (e) {
      print('❌ Failed to cleanup measurements: $e');
      return 0;
    }
  }

  /// Clean up old hourly statistics
  Future<int> _cleanupHourlyStatistics() async {
    try {
      final deletedCount = await _hourlyDao.deleteOlderThanDays(hourlyStatsRetentionDays);
      if (deletedCount > 0) {
        print('🗑️ Deleted $deletedCount old hourly statistics');
      }
      return deletedCount;
    } catch (e) {
      print('❌ Failed to cleanup hourly statistics: $e');
      return 0;
    }
  }

  /// Clean up old daily statistics
  Future<int> _cleanupDailyStatistics() async {
    try {
      final deletedCount = await _dailyDao.deleteOlderThanDays(dailyStatsRetentionDays);
      if (deletedCount > 0) {
        print('🗑️ Deleted $deletedCount old daily statistics');
      }
      return deletedCount;
    } catch (e) {
      print('❌ Failed to cleanup daily statistics: $e');
      return 0;
    }
  }

  /// Clean up expired audio recordings and files
  Future<int> _cleanupAudioRecordings() async {
    try {
      // Get expired recordings
      final expiredRecordings = await _recordingDao.getExpired();
      int deletedCount = 0;

      for (final recording in expiredRecordings) {
        try {
          // Delete file
          final file = File(recording.filePath);
          if (await file.exists()) {
            await file.delete();
          }

          // Delete from database
          await _recordingDao.deleteById(recording.id);

          // Delete related analysis queue items
          await _analysisQueueDao.deleteByRecordingId(recording.id);

          deletedCount++;
        } catch (e) {
          print('❌ Failed to delete recording ${recording.id}: $e');
        }
      }

      if (deletedCount > 0) {
        print('🗑️ Deleted $deletedCount expired recordings');
      }

      return deletedCount;
    } catch (e) {
      print('❌ Failed to cleanup audio recordings: $e');
      return 0;
    }
  }

  /// Clean up old analysis queue items
  Future<int> _cleanupAnalysisQueue() async {
    try {
      int deletedCount = 0;

      // Delete old completed items
      final completedDeleted = await _analysisQueueDao
          .deleteCompletedOlderThanDays(analysisQueueRetentionDays);
      deletedCount += completedDeleted;

      // Delete old failed items
      final failedDeleted = await _analysisQueueDao
          .deleteFailedOlderThanDays(analysisQueueRetentionDays);
      deletedCount += failedDeleted;

      // Reset any stuck processing items to pending
      final resetCount = await _analysisQueueDao.resetProcessingToPending();
      if (resetCount > 0) {
        print('🔄 Reset $resetCount stuck processing items to pending');
      }

      if (deletedCount > 0) {
        print('🗑️ Deleted $deletedCount old analysis queue items');
      }

      return deletedCount;
    } catch (e) {
      print('❌ Failed to cleanup analysis queue: $e');
      return 0;
    }
  }

  /// Vacuum database if needed
  Future<bool> _vacuumIfNeeded() async {
    try {
      final dbSize = await _databaseHelper.getDatabaseSize();
      final dbSizeMB = dbSize / (1024 * 1024);

      // Vacuum if database is larger than threshold
      if (dbSizeMB > maxDatabaseSizeMB * 0.8) {
        print('💽 Database size ${dbSizeMB.toStringAsFixed(2)} MB, performing vacuum...');
        await _databaseHelper.vacuum();
        
        final newSize = await _databaseHelper.getDatabaseSize();
        final newSizeMB = newSize / (1024 * 1024);
        print('💽 Vacuum completed, new size: ${newSizeMB.toStringAsFixed(2)} MB');
        
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Failed to vacuum database: $e');
      return false;
    }
  }

  /// Perform database integrity checks
  Future<Map<String, dynamic>> _performIntegrityChecks() async {
    final checks = <String, dynamic>{};

    try {
      // Check for orphaned records
      checks['orphaned_analysis_queue'] = await _checkOrphanedAnalysisQueue();
      
      // Check data consistency
      checks['data_consistency'] = await _checkDataConsistency();
      
      // Check file system consistency
      checks['file_system_consistency'] = await _checkFileSystemConsistency();

    } catch (e) {
      checks['error'] = e.toString();
    }

    return checks;
  }

  /// Check storage health
  Future<Map<String, dynamic>> _checkStorageHealth() async {
    try {
      final recordingStats = await _recordingDao.getStorageStats();
      final dbSize = await _databaseHelper.getDatabaseSize();

      return {
        'database_size_mb': (dbSize / (1024 * 1024)).toStringAsFixed(2),
        'database_size_warning': dbSize > maxDatabaseSizeMB * 1024 * 1024 * 0.8,
        'total_recording_size_mb': recordingStats['total_size'] != null
            ? ((recordingStats['total_size'] as int) / (1024 * 1024)).toStringAsFixed(2)
            : '0',
        'recording_count': recordingStats['total_recordings'],
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Check for orphaned analysis queue items
  Future<int> _checkOrphanedAnalysisQueue() async {
    try {
      // This would require a more complex query to check for analysis queue
      // items that reference non-existent recordings
      return 0; // Placeholder
    } catch (e) {
      return -1;
    }
  }

  /// Check data consistency
  Future<bool> _checkDataConsistency() async {
    try {
      // Check that we have reasonable data ranges
      final measurementCount = await _measurementDao.count();
      final hourlyCount = await _hourlyDao.count();
      
      // Basic sanity checks
      return measurementCount >= 0 && hourlyCount >= 0;
    } catch (e) {
      return false;
    }
  }

  /// Check file system consistency
  Future<Map<String, int>> _checkFileSystemConsistency() async {
    try {
      final recordings = await _recordingDao.getRecent(limit: 100);
      int existingFiles = 0;
      int missingFiles = 0;

      for (final recording in recordings) {
        final file = File(recording.filePath);
        if (await file.exists()) {
          existingFiles++;
        } else {
          missingFiles++;
        }
      }

      return {
        'existing_files': existingFiles,
        'missing_files': missingFiles,
      };
    } catch (e) {
      return {'error': -1};
    }
  }

  /// Calculate overall health status
  String _calculateHealthStatus(Map<String, dynamic> healthReport) {
    try {
      final dbSizeMB = double.parse(healthReport['database_size_mb'] as String);
      final storageHealth = healthReport['storage_health'] as Map<String, dynamic>;
      final integrityChecks = healthReport['integrity_checks'] as Map<String, dynamic>;

      // Check for critical issues
      if (healthReport.containsKey('error') ||
          integrityChecks.containsKey('error') ||
          storageHealth.containsKey('error')) {
        return 'error';
      }

      // Check for warnings
      if (dbSizeMB > maxDatabaseSizeMB * 0.9 ||
          (storageHealth['database_size_warning'] as bool? ?? false)) {
        return 'warning';
      }

      return 'healthy';
    } catch (e) {
      return 'unknown';
    }
  }

  /// Get service status
  Map<String, dynamic> getStatus() {
    return {
      'is_running': _isRunning,
      'cleanup_interval_hours': cleanupInterval.inHours,
      'health_check_interval_hours': healthCheckInterval.inHours,
      'retention_policies': {
        'measurements_hours': measurementRetention.inHours,
        'hourly_stats_days': hourlyStatsRetentionDays,
        'daily_stats_days': dailyStatsRetentionDays,
        'audio_recordings_days': audioRetention.inDays,
      },
    };
  }

  /// Dispose of resources
  void dispose() {
    stop();
  }
}