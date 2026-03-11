import 'package:get_it/get_it.dart';

import '../services/cactus_ai_service.dart';
import '../services/noise_pattern_analyzer.dart';
import '../services/ai_analysis_service.dart';
import '../services/intelligent_recommendation_engine.dart';
import '../services/audio_processing_service.dart';
import '../core/logging/app_logger.dart';

/// Example demonstrating the AI-powered noise analysis pipeline
class AIIntegrationExample {
  static Future<void> demonstrateAIAnalysis() async {
    try {
      AppLogger.ai('🚀 Starting AI Integration Example');

      // Get services from dependency injection
      final cactusService = GetIt.instance<CactusAIService>();
      final patternAnalyzer = GetIt.instance<NoisePatternAnalyzer>();
      final aiAnalysisService = GetIt.instance<AIAnalysisService>();
      final recommendationEngine = GetIt.instance<IntelligentRecommendationEngine>();

      // Initialize AI services
      AppLogger.ai('🔧 Initializing AI services...');
      final aiInitialized = await aiAnalysisService.initialize();

      if (!aiInitialized) {
        AppLogger.ai('⚠️ AI services not available, running in fallback mode');
      }

      // Example 1: Analyze simulated noise measurements
      final exampleMeasurements = _generateExampleMeasurements();

      AppLogger.ai('📊 Analyzing ${exampleMeasurements.length} noise measurements...');

      final patternData = patternAnalyzer.analyzePattern(
        measurements: exampleMeasurements,
        eventStart: DateTime.now().subtract(const Duration(minutes: 15)),
        eventEnd: DateTime.now(),
      );

      AppLogger.ai('🔍 Pattern Analysis Results:');
      AppLogger.ai('  - Mean SPL: ${patternData['statistics']['mean']?.toStringAsFixed(1)} dBA');
      AppLogger.ai('  - Peak Count: ${patternData['peak_analysis']['peak_count']}');
      AppLogger.ai('  - Variability: ${patternData['variability']['variability_class']}');
      AppLogger.ai('  - Time Pattern: ${patternData['time_of_day']}');

      // Example 2: Generate AI insights (if available)
      if (aiInitialized && cactusService.isReady) {
        AppLogger.ai('🤖 Generating AI insights...');

        final aiInsights = await cactusService.analyzeNoisePattern(
          measurementData: patternData,
          timeContext: 'evening weekday',
          locationContext: 'urban residential area',
        );

        if (aiInsights != null) {
          AppLogger.ai('🧠 AI Analysis Results:');
          AppLogger.ai('  - Classification: ${aiInsights['classification']}');
          AppLogger.ai('  - Confidence: ${(aiInsights['confidence'] * 100).toStringAsFixed(1)}%');
          AppLogger.ai('  - Health Impact: ${aiInsights['insights']['health_impact']}');
        }
      }

      // Example 3: Generate intelligent recommendations
      AppLogger.ai('💡 Generating recommendations...');

      final mockAnalysisResult = {
        'classification': 'traffic_noise',
        'confidence': 0.85,
        'insights': {
          'health_impact': 'moderate',
          'patterns': ['evening_peak', 'consistent_baseline']
        }
      };

      final recommendations = await recommendationEngine.generateRecommendations(
        analysisResult: mockAnalysisResult,
        recentEvents: [
          {
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'spl_value': 68.5,
            'classification': 'traffic_noise'
          }
        ],
        deviceContext: {
          'location_type': 'residential',
          'calibration_status': 'calibrated'
        },
      );

      AppLogger.ai('📋 Intelligent Recommendations:');
      final recList = recommendations['recommendations'] as List<dynamic>;
      for (int i = 0; i < recList.length && i < 3; i++) {
        final rec = recList[i] as Map<String, dynamic>;
        AppLogger.ai('  ${i + 1}. ${rec['action']} (Priority: ${rec['priority']})');
      }

      AppLogger.success('✅ AI Integration Example completed successfully');

    } catch (e, stackTrace) {
      AppLogger.error('❌ AI Integration Example failed: $e', e, stackTrace);
    }
  }

  /// Generate example noise measurements for testing
  static List<TimestampedSPL> _generateExampleMeasurements() {
    final measurements = <TimestampedSPL>[];
    final now = DateTime.now();

    // Simulate 15 minutes of measurements (one per minute)
    for (int i = 0; i < 15; i++) {
      final timestamp = now.subtract(Duration(minutes: 14 - i));

      // Simulate traffic noise pattern: higher during rush hour
      double baseSpl = 55.0; // Background level
      if (i >= 7 && i <= 10) {
        baseSpl += 8.0; // Rush hour increase
      }

      // Add some randomness
      final random = (i * 17) % 11 - 5; // Pseudo-random -5 to +5
      final spl = baseSpl + random;

      measurements.add(TimestampedSPL(
        timestamp: timestamp,
        splDb: spl,
      ));
    }

    return measurements;
  }
}
