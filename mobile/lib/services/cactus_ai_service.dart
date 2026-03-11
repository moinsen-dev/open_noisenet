import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cactus/cactus.dart';
import 'package:path_provider/path_provider.dart';

import '../core/logging/app_logger.dart';

/// Service for intelligent noise analysis using Cactus LLM framework
class CactusAIService {
  static final CactusAIService _instance = CactusAIService._internal();
  factory CactusAIService() => _instance;
  CactusAIService._internal();

  CactusLM? _llm;
  bool _isInitialized = false;
  String? _modelPath;

  /// Initialize the Cactus AI service with a small efficient model
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      AppLogger.ai('Initializing Cactus AI Service...');

      // Initialize the Cactus LM
      _llm = CactusLM();

      // Download a small, efficient model for noise analysis
      // Using Qwen-0.5B for mobile efficiency
      const modelUrl = 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf';

      try {
        await _llm!.download(modelUrl: modelUrl);
        AppLogger.ai('Model downloaded successfully');
      } catch (e) {
        AppLogger.ai('Model download failed, checking for existing model: $e');
        // Continue - model might already exist
      }

      // Initialize with optimized settings for mobile
      await _llm!.init(
        contextSize: 1024,  // Smaller context for efficiency
        threads: 2,        // Limit threads for battery life
      );

      _isInitialized = true;
      AppLogger.success('Cactus AI Service initialized successfully');
      return true;

    } catch (e) {
      AppLogger.ai('Failed to initialize Cactus AI Service: $e');
      return false;
    }
  }

  /// Analyze noise event patterns using LLM intelligence
  Future<Map<String, dynamic>?> analyzeNoisePattern({
    required Map<String, dynamic> measurementData,
    required String timeContext,
    required String locationContext,
  }) async {
    if (!_isInitialized || _llm == null) {
      AppLogger.ai('AI service not initialized');
      return null;
    }

    try {
      // Extract key metrics from measurement data
      final avgSPL = measurementData['average_spl_db'] as double? ?? 0.0;
      final peakSPL = measurementData['peak_spl_db'] as double? ?? 0.0;
      final duration = measurementData['duration_seconds'] as int? ?? 0;
      final stdDev = measurementData['spl_std_dev'] as double? ?? 0.0;
      final measurements = measurementData['spl_sequence'] as List<double>? ?? [];

      // Create intelligent analysis prompt
      final prompt = _buildAnalysisPrompt(
        avgSPL: avgSPL,
        peakSPL: peakSPL,
        duration: duration,
        stdDev: stdDev,
        timeContext: timeContext,
        locationContext: locationContext,
        measurements: measurements,
      );

      // Generate analysis using LLM
      final response = await _llm!.completion([
        ChatMessage(role: 'user', content: prompt)
      ], maxTokens: 200, temperature: 0.3);

      // Parse the LLM response
      return _parseAnalysisResponse(response.text, measurementData);

    } catch (e) {
      AppLogger.ai('Error in noise pattern analysis: $e');
      return null;
    }
  }

  /// Build intelligent analysis prompt for noise classification
  String _buildAnalysisPrompt({
    required double avgSPL,
    required double peakSPL,
    required int duration,
    required double stdDev,
    required String timeContext,
    required String locationContext,
    required List<double> measurements,
  }) {
    // Calculate additional pattern metrics
    final variability = stdDev / avgSPL * 100; // Coefficient of variation
    final peakRatio = peakSPL / avgSPL;
    final isImpulsive = peakRatio > 1.5 && duration < 60;
    final isSustained = duration > 300 && variability < 20;

    return '''
You are an expert acoustic analyst. Analyze this noise event and respond with JSON only:

MEASUREMENT DATA:
- Average SPL: ${avgSPL.toStringAsFixed(1)} dB
- Peak SPL: ${peakSPL.toStringAsFixed(1)} dB
- Duration: ${duration} seconds
- Variability: ${variability.toStringAsFixed(1)}%
- Pattern: ${isImpulsive ? 'Impulsive' : isSustained ? 'Sustained' : 'Variable'}
- Time: $timeContext
- Location: $locationContext

Respond with JSON:
{
  "classification": "primary_category",
  "confidence": 0.85,
  "likely_source": "specific description",
  "characteristics": ["feature1", "feature2"],
  "health_impact": "low|moderate|high",
  "regulatory_status": "compliant|violation",
  "recommendations": ["action1", "action2"]
}

Categories: traffic_noise, construction_activity, aircraft_noise, industrial_noise, human_activity, emergency_vehicle, natural_sounds, hvac_systems, impulsive_event, unknown

Consider:
- WHO noise guidelines (Day: 55dB, Evening: 50dB, Night: 40dB)
- Duration patterns for source identification
- Time-of-day context for likelihood assessment
- Peak-to-average ratio for event characterization
''';
  }

  /// Parse LLM response into structured analysis data
  Map<String, dynamic>? _parseAnalysisResponse(String response, Map<String, dynamic> originalData) {
    try {
      // Extract JSON from response
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;

      if (jsonStart == -1 || jsonEnd <= jsonStart) {
        throw FormatException('No valid JSON found in LLM response');
      }

      final jsonString = response.substring(jsonStart, jsonEnd);
      final parsed = json.decode(jsonString) as Map<String, dynamic>;

      // Validate and enhance the response
      return {
        'classification': parsed['classification'] ?? 'unknown',
        'confidence': _validateConfidence(parsed['confidence']),
        'likely_source': parsed['likely_source'] ?? 'Unidentified noise source',
        'characteristics': parsed['characteristics'] ?? [],
        'health_impact': parsed['health_impact'] ?? 'moderate',
        'regulatory_status': parsed['regulatory_status'] ?? 'unknown',
        'recommendations': parsed['recommendations'] ?? [],

        // Add metadata
        'analysis_timestamp': DateTime.now().toIso8601String(),
        'model_version': 'Qwen2.5-0.5B-Instruct',
        'analysis_method': 'cactus_llm',
        'original_measurements': originalData,
        'raw_llm_response': response,
      };

    } catch (e) {
      AppLogger.ai('Error parsing LLM response: $e');

      // Fallback to rule-based analysis
      return _fallbackAnalysis(originalData, response);
    }
  }

  /// Validate confidence score from LLM
  double _validateConfidence(dynamic confidence) {
    if (confidence is num) {
      return confidence.toDouble().clamp(0.0, 1.0);
    }
    return 0.5; // Default confidence
  }

  /// Fallback analysis when LLM parsing fails
  Map<String, dynamic> _fallbackAnalysis(Map<String, dynamic> data, String rawResponse) {
    final avgSPL = data['average_spl_db'] as double? ?? 0.0;
    final duration = data['duration_seconds'] as int? ?? 0;

    // Simple rule-based classification as fallback
    String classification = 'unknown';
    String likelySource = 'Unable to determine from measurement data';
    double confidence = 0.3;

    if (avgSPL > 75 && duration < 120) {
      classification = 'impulsive_event';
      likelySource = 'Brief loud event - possibly construction or vehicle';
      confidence = 0.6;
    } else if (avgSPL > 65 && duration > 300) {
      classification = 'traffic_noise';
      likelySource = 'Sustained moderate noise - likely traffic';
      confidence = 0.7;
    } else if (avgSPL < 50) {
      classification = 'natural_sounds';
      likelySource = 'Low-level ambient sound';
      confidence = 0.5;
    }

    return {
      'classification': classification,
      'confidence': confidence,
      'likely_source': likelySource,
      'characteristics': ['fallback_analysis'],
      'health_impact': avgSPL > 70 ? 'moderate' : 'low',
      'regulatory_status': 'requires_manual_review',
      'recommendations': ['Manual review recommended due to analysis failure'],
      'analysis_timestamp': DateTime.now().toIso8601String(),
      'model_version': 'fallback_rules',
      'analysis_method': 'rule_based_fallback',
      'raw_llm_response': rawResponse,
      'fallback_reason': 'LLM response parsing failed',
    };
  }

  /// Generate contextual summary of multiple events
  Future<String?> generateEventSummary({
    required List<Map<String, dynamic>> events,
    required String timeframe,
  }) async {
    if (!_isInitialized || _llm == null || events.isEmpty) return null;

    try {
      final prompt = '''
Summarize these noise events from the past $timeframe. Provide a brief community noise assessment:

Events:
${events.map((e) => '- ${e['classification']}: ${e['average_spl_db']}dB for ${e['duration_seconds']}s').join('\n')}

Provide 2-3 sentences covering:
1. Overall noise environment
2. Main concerns or patterns
3. Recommended actions

Focus on practical community impact.
''';

      final response = await _llm!.completion([
        ChatMessage(role: 'user', content: prompt)
      ], maxTokens: 150, temperature: 0.4);

      return response.text.trim();

    } catch (e) {
      AppLogger.ai('Error generating event summary: $e');
      return null;
    }
  }

  /// Check if service is ready
  bool get isReady => _isInitialized && _llm != null;

  /// Get model information
  Map<String, dynamic> getModelInfo() {
    return {
      'model_name': 'Qwen2.5-0.5B-Instruct',
      'model_format': 'GGUF',
      'quantization': 'Q4_K_M',
      'is_initialized': _isInitialized,
      'framework': 'Cactus LLM',
      'context_size': 1024,
      'specialization': 'noise_pattern_analysis',
      'capabilities': [
        'contextual_classification',
        'regulatory_assessment',
        'health_impact_analysis',
        'recommendation_generation'
      ]
    };
  }

  /// Dispose of resources
  Future<void> dispose() async {
    try {
      // Cactus LM disposal (if available in API)
      _llm = null;
      _isInitialized = false;
      AppLogger.ai('Cactus AI Service disposed');
    } catch (e) {
      AppLogger.ai('Error disposing AI service: $e');
    }
  }
}

/// Extension methods for logging
extension on AppLogger {
  static void ai(String message) {
    AppLogger.info('[AI] $message');
  }
}
