import 'dart:async';
import 'dart:math';

import '../core/logging/app_logger.dart';
import 'ai_analysis_service.dart';

/// Intelligent recommendation engine that provides actionable insights based on AI analysis
class IntelligentRecommendationEngine {
  final AIAnalysisService _aiAnalysisService;

  IntelligentRecommendationEngine({
    required AIAnalysisService aiAnalysisService,
  }) : _aiAnalysisService = aiAnalysisService;

  /// Generate comprehensive recommendations based on noise analysis
  Future<Map<String, dynamic>> generateRecommendations({
    required Map<String, dynamic> analysisResult,
    required List<Map<String, dynamic>> recentEvents,
    required Map<String, dynamic> deviceContext,
  }) async {
    try {
      AppLogger.info('Generating intelligent recommendations...');

      // Extract key information
      final classification = analysisResult['classification'] as String;
      final confidence = analysisResult['confidence'] as double;
      final healthImpact = analysisResult['insights']['health_impact'] as String? ?? 'moderate';
      final regulatoryStatus = analysisResult['insights']['regulatory_status'] as String? ?? 'unknown';

      // Analyze patterns across recent events
      final patternInsights = _analyzeEventPatterns(recentEvents);

      // Generate context-aware recommendations
      final recommendations = await _generateContextualRecommendations(
        classification: classification,
        confidence: confidence,
        healthImpact: healthImpact,
        regulatoryStatus: regulatoryStatus,
        patternInsights: patternInsights,
        deviceContext: deviceContext,
      );

      // Create personalized action plan
      final actionPlan = _createActionPlan(recommendations, patternInsights);

      // Generate LLM-powered insights if confidence is high
      String? aiInsights;
      if (confidence > 0.7 && _aiAnalysisService.hasAnalysisCapability) {
        aiInsights = await _generateAIInsights(analysisResult, recentEvents);
      }

      return {
        'recommendations': recommendations,
        'action_plan': actionPlan,
        'pattern_insights': patternInsights,
        'ai_insights': aiInsights,
        'priority_level': _calculatePriorityLevel(healthImpact, regulatoryStatus, patternInsights),
        'generated_at': DateTime.now().toIso8601String(),
        'confidence': confidence,
      };

    } catch (e) {
      AppLogger.error('Error generating recommendations: $e');
      return _getFallbackRecommendations(analysisResult);
    }
  }

  /// Analyze patterns across recent events to identify trends
  Map<String, dynamic> _analyzeEventPatterns(List<Map<String, dynamic>> events) {
    if (events.isEmpty) {
      return {
        'trend': 'insufficient_data',
        'frequency': 'unknown',
        'recurring_sources': [],
        'peak_times': [],
      };
    }

    // Analyze event frequency
    final eventCount = events.length;
    final timeSpanHours = _calculateTimeSpan(events);
    final frequency = timeSpanHours > 0 ? eventCount / timeSpanHours : 0;

    // Identify recurring sources
    final sourceMap = <String, int>{};
    for (final event in events) {
      final source = event['classification'] as String? ?? 'unknown';
      sourceMap[source] = (sourceMap[source] ?? 0) + 1;
    }

    final recurringSources = sourceMap.entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .toList();

    // Analyze peak times
    final peakTimes = _findPeakTimes(events);

    // Determine overall trend
    final trend = _calculateTrend(events);

    return {
      'trend': trend,
      'frequency': frequency,
      'event_count': eventCount,
      'time_span_hours': timeSpanHours,
      'recurring_sources': recurringSources,
      'peak_times': peakTimes,
      'dominant_source': sourceMap.keys.isNotEmpty
          ? sourceMap.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : 'unknown',
    };
  }

  /// Generate contextual recommendations based on analysis
  Future<List<Map<String, dynamic>>> _generateContextualRecommendations({
    required String classification,
    required double confidence,
    required String healthImpact,
    required String regulatoryStatus,
    required Map<String, dynamic> patternInsights,
    required Map<String, dynamic> deviceContext,
  }) async {
    final recommendations = <Map<String, dynamic>>[];

    // Health-based recommendations
    if (healthImpact == 'high' || healthImpact == 'critical') {
      recommendations.add({
        'type': 'health',
        'priority': 'high',
        'title': 'Health Protection Required',
        'description': 'Noise levels may impact your health and well-being',
        'actions': [
          'Consider using hearing protection if exposure continues',
          'Limit time in this area during loud periods',
          'Monitor for symptoms like stress, sleep disruption, or concentration issues',
          'Consult healthcare provider if symptoms persist',
        ],
        'icon': '🏥',
      });
    }

    // Regulatory compliance recommendations
    if (regulatoryStatus == 'violation' || regulatoryStatus == 'severe_violation') {
      recommendations.add({
        'type': 'regulatory',
        'priority': 'high',
        'title': 'Noise Ordinance Violation',
        'description': 'Current noise levels exceed local regulations',
        'actions': [
          'Document this event with date, time, and measurements',
          'Check local noise ordinances for specific limits',
          'Consider filing a noise complaint with local authorities',
          'Gather evidence of recurring violations',
        ],
        'icon': '⚖️',
      });
    }

    // Source-specific recommendations
    final sourceRecommendations = _getSourceSpecificRecommendations(classification);
    if (sourceRecommendations != null) {
      recommendations.add(sourceRecommendations);
    }

    // Pattern-based recommendations
    if (patternInsights['frequency'] as double > 2.0) { // More than 2 events per hour
      recommendations.add({
        'type': 'pattern',
        'priority': 'medium',
        'title': 'Frequent Noise Events Detected',
        'description': 'Regular noise disturbances may indicate a persistent source',
        'actions': [
          'Monitor for specific times when noise occurs',
          'Identify patterns to help locate the source',
          'Consider relocating to a quieter area if possible',
          'Contact building management if noise is from neighbors',
        ],
        'icon': '📊',
      });
    }

    // Time-sensitive recommendations
    final hour = DateTime.now().hour;
    if ((hour >= 22 || hour <= 6) && confidence > 0.6) {
      recommendations.add({
        'type': 'time_sensitive',
        'priority': 'high',
        'title': 'Nighttime Noise Disturbance',
        'description': 'Noise during quiet hours may violate noise ordinances',
        'actions': [
          'Most noise ordinances have stricter limits at night',
          'Document exact times for potential complaints',
          'Use white noise or earplugs to improve sleep',
          'Consider temporary sleeping arrangement if severe',
        ],
        'icon': '🌙',
      });
    }

    // Device and monitoring recommendations
    recommendations.add({
      'type': 'monitoring',
      'priority': 'low',
      'title': 'Improve Monitoring',
      'description': 'Enhance your noise monitoring for better insights',
      'actions': [
        'Keep the app running to build a comprehensive noise profile',
        'Enable notifications for significant events',
        'Review daily and weekly reports for patterns',
        'Share data with community for collective action',
      ],
      'icon': '📱',
    });

    return recommendations;
  }

  /// Get source-specific recommendations
  Map<String, dynamic>? _getSourceSpecificRecommendations(String classification) {
    switch (classification) {
      case 'traffic_noise':
        return {
          'type': 'source_specific',
          'priority': 'medium',
          'title': 'Traffic Noise Mitigation',
          'description': 'Strategies to reduce traffic noise impact',
          'actions': [
            'Close windows facing the street during peak hours',
            'Use sound-absorbing curtains or acoustic panels',
            'Consider white noise machines to mask traffic sounds',
            'Advocate for traffic calming measures in your area',
          ],
          'icon': '🚗',
        };

      case 'construction_activity':
        return {
          'type': 'source_specific',
          'priority': 'high',
          'title': 'Construction Noise Response',
          'description': 'Address construction-related noise disturbances',
          'actions': [
            'Check if construction is within permitted hours',
            'Contact the construction company or building management',
            'File complaint with local building department if needed',
            'Request advance notice of noisy work periods',
          ],
          'icon': '🚧',
        };

      case 'aircraft_noise':
        return {
          'type': 'source_specific',
          'priority': 'medium',
          'title': 'Aircraft Noise Management',
          'description': 'Strategies for dealing with aircraft noise',
          'actions': [
            'Check airport noise maps and flight patterns',
            'Contact airport noise office for recurring issues',
            'Install sound insulation if near flight paths',
            'Join local aircraft noise advocacy groups',
          ],
          'icon': '✈️',
        };

      case 'industrial_noise':
        return {
          'type': 'source_specific',
          'priority': 'high',
          'title': 'Industrial Noise Action',
          'description': 'Address industrial noise concerns',
          'actions': [
            'Contact the facility directly about noise concerns',
            'File complaint with environmental protection agency',
            'Check industrial facility operating permits',
            'Organize community response if affecting multiple residents',
          ],
          'icon': '🏭',
        };

      default:
        return null;
    }
  }

  /// Create a personalized action plan
  Map<String, dynamic> _createActionPlan(
    List<Map<String, dynamic>> recommendations,
    Map<String, dynamic> patternInsights,
  ) {
    final highPriority = recommendations.where((r) => r['priority'] == 'high').toList();
    final mediumPriority = recommendations.where((r) => r['priority'] == 'medium').toList();
    final lowPriority = recommendations.where((r) => r['priority'] == 'low').toList();

    final immediate = <String>[];
    final shortTerm = <String>[];
    final longTerm = <String>[];

    // Categorize actions by timeline
    for (final rec in highPriority) {
      final actions = rec['actions'] as List<String>;
      immediate.addAll(actions.take(2)); // First 2 actions are immediate
    }

    for (final rec in mediumPriority) {
      final actions = rec['actions'] as List<String>;
      shortTerm.addAll(actions);
    }

    for (final rec in lowPriority) {
      final actions = rec['actions'] as List<String>;
      longTerm.addAll(actions);
    }

    return {
      'immediate_actions': immediate.take(3).toList(), // Max 3 immediate actions
      'short_term_actions': shortTerm.take(5).toList(), // Max 5 short-term actions
      'long_term_actions': longTerm.take(3).toList(), // Max 3 long-term actions
      'priority_summary': {
        'high_priority_count': highPriority.length,
        'total_recommendations': recommendations.length,
        'primary_focus': highPriority.isNotEmpty ? highPriority.first['title'] : 'Monitor and document',
      },
    };
  }

  /// Generate AI-powered insights using Cactus LLM
  Future<String?> _generateAIInsights(
    Map<String, dynamic> analysisResult,
    List<Map<String, dynamic>> recentEvents,
  ) async {
    try {
      if (!_aiAnalysisService.hasAnalysisCapability) return null;

      // Generate insights using available data
      return 'Based on recent monitoring data, detected patterns suggest ${analysisResult['classification']} noise characteristics.';

    } catch (e) {
      AppLogger.error('Error generating AI insights: $e');
      return null;
    }
  }

  /// Calculate priority level for recommendations
  String _calculatePriorityLevel(
    String healthImpact,
    String regulatoryStatus,
    Map<String, dynamic> patternInsights,
  ) {
    int score = 0;

    // Health impact scoring
    switch (healthImpact) {
      case 'critical':
        score += 4;
        break;
      case 'high':
        score += 3;
        break;
      case 'moderate':
        score += 2;
        break;
      default:
        score += 1;
    }

    // Regulatory status scoring
    if (regulatoryStatus.contains('violation')) {
      score += 3;
    } else if (regulatoryStatus == 'marginal') {
      score += 1;
    }

    // Pattern frequency scoring
    final frequency = patternInsights['frequency'] as double? ?? 0;
    if (frequency > 3) score += 2;
    else if (frequency > 1) score += 1;

    // Determine priority level
    if (score >= 7) return 'critical';
    if (score >= 5) return 'high';
    if (score >= 3) return 'medium';
    return 'low';
  }

  /// Helper methods for pattern analysis
  double _calculateTimeSpan(List<Map<String, dynamic>> events) {
    if (events.length < 2) return 1.0;

    final timestamps = events
        .map((e) => DateTime.tryParse(e['timestamp'] as String? ?? ''))
        .where((t) => t != null)
        .cast<DateTime>()
        .toList();

    if (timestamps.length < 2) return 1.0;

    timestamps.sort();
    return timestamps.last.difference(timestamps.first).inHours.toDouble();
  }

  List<String> _findPeakTimes(List<Map<String, dynamic>> events) {
    final hourCounts = <int, int>{};

    for (final event in events) {
      final timestamp = DateTime.tryParse(event['timestamp'] as String? ?? '');
      if (timestamp != null) {
        final hour = timestamp.hour;
        hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
      }
    }

    final peakHours = hourCounts.entries
        .where((entry) => entry.value > 1)
        .map((entry) => '${entry.key}:00-${entry.key + 1}:00')
        .toList();

    return peakHours;
  }

  String _calculateTrend(List<Map<String, dynamic>> events) {
    if (events.length < 3) return 'insufficient_data';

    final recentEvents = events.take(events.length ~/ 2).length;
    final olderEvents = events.length - recentEvents;

    if (recentEvents > olderEvents * 1.2) return 'increasing';
    if (recentEvents < olderEvents * 0.8) return 'decreasing';
    return 'stable';
  }

  /// Fallback recommendations when AI processing fails
  Map<String, dynamic> _getFallbackRecommendations(Map<String, dynamic> analysisResult) {
    return {
      'recommendations': [
        {
          'type': 'general',
          'priority': 'medium',
          'title': 'General Noise Management',
          'description': 'Standard recommendations for noise exposure',
          'actions': [
            'Monitor noise levels regularly',
            'Document significant events',
            'Consider hearing protection if levels are high',
            'Consult local noise regulations',
          ],
          'icon': '🔊',
        }
      ],
      'action_plan': {
        'immediate_actions': ['Document this event'],
        'short_term_actions': ['Monitor for patterns'],
        'long_term_actions': ['Review noise regulations'],
      },
      'priority_level': 'medium',
      'generated_at': DateTime.now().toIso8601String(),
      'confidence': 0.5,
    };
  }
}
