import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Application-wide logging service using Talker
/// Provides structured logging for debugging, monitoring, and production use
class AppLogger {
  static late final Talker _talker;
  
  /// Initialize the logger - should be called once during app startup
  static void initialize({bool enableInRelease = false}) {
    _talker = TalkerFlutter.init(
      settings: TalkerSettings(
        enabled: kDebugMode || enableInRelease,
        useConsoleLogs: kDebugMode,
        maxHistoryItems: 1000,
      ),
    );
    
    // Log initialization
    info('🚀 AppLogger initialized');
  }
  
  /// Get the Talker instance for advanced usage
  static Talker get instance => _talker;
  
  // Convenience methods for different log levels
  
  /// Log debug information (only in debug mode)
  static void debug(String message, [Object? exception, StackTrace? stackTrace]) {
    _talker.debug(message, exception, stackTrace);
  }
  
  /// Log general information
  static void info(String message, [Object? exception, StackTrace? stackTrace]) {
    _talker.info(message, exception, stackTrace);
  }
  
  /// Log warnings
  static void warning(String message, [Object? exception, StackTrace? stackTrace]) {
    _talker.warning(message, exception, stackTrace);
  }
  
  /// Log errors
  static void error(String message, [Object? exception, StackTrace? stackTrace]) {
    _talker.error(message, exception, stackTrace);
  }
  
  /// Log critical errors
  static void critical(String message, [Object? exception, StackTrace? stackTrace]) {
    _talker.critical(message, exception, stackTrace);
  }
  
  /// Log with custom message
  static void log(String message) {
    _talker.info(message);
  }
  
  // Service-specific logging methods
  
  /// Audio service logging
  static void audio(String message) {
    _talker.info('🎤 $message');
  }
  
  /// Background service logging  
  static void background(String message) {
    _talker.info('📱 $message');
  }
  
  /// Event detection logging
  static void event(String message) {
    _talker.info('🚨 $message');
  }
  
  /// Network/API logging
  static void network(String message) {
    _talker.info('🌐 $message');
  }
  
  /// Database logging
  static void database(String message) {
    _talker.info('💾 $message');
  }
  
  /// Recording service logging
  static void recording(String message) {
    _talker.info('📼 $message');
  }
  
  /// Statistics logging
  static void stats(String message) {
    _talker.info('📊 $message');
  }
  
  /// Settings/preferences logging
  static void settings(String message) {
    _talker.info('⚙️ $message');
  }
  
  /// Authentication logging
  static void auth(String message) {
    _talker.info('🔐 $message');
  }
  
  /// Location service logging
  static void location(String message) {
    _talker.info('📍 $message');
  }
  
  /// Performance monitoring
  static void performance(String message) {
    _talker.info('⚡ $message');
  }
  
  /// UI/UX logging
  static void ui(String message) {
    _talker.info('🎨 $message');
  }
  
  /// Success operations
  static void success(String message) {
    _talker.info('✅ $message');
  }
  
  /// Failed operations
  static void failure(String message, [Object? exception, StackTrace? stackTrace]) {
    _talker.error('❌ $message', exception, stackTrace);
  }
  
  /// Handle exceptions with context
  static void exception(Object exception, StackTrace stackTrace, [String? message]) {
    _talker.handle(exception, stackTrace, message);
  }
  
  /// Clear log history
  static void clearLogs() {
    _talker.cleanHistory();
    info('🧹 Log history cleared');
  }
  
  /// Get log history for export or debugging
  static List<TalkerData> getHistory() {
    return _talker.history;
  }
  
  /// Get formatted log history as string
  static String getFormattedHistory() {
    return _talker.history
        .map((log) => '${log.displayTime} [${log.logLevel.toString().toUpperCase()}] ${log.displayMessage}')
        .join('\n');
  }
  
  /// Permission-related logging
  static void permission(String message) {
    _talker.info('🔑 $message');
  }
  
  /// Onboarding flow logging
  static void onboarding(String message) {
    _talker.info('👋 $message');
  }
}