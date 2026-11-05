import 'dart:convert';

import '../../../core/database/models/noise_measurement.dart';
import 'noise_history.dart';
import '../../../services/sound_analysis/acoustic_phase.dart';

/// An explicit, unencrypted export of the selected time window. Do not include
/// device identifiers, coordinates, diary text, credentials or raw model audio.
String historyExportJson({
  required List<NoiseMeasurement> minutes,
  required List<SourceHistoryEntry> hints,
  required DateTime start,
  required DateTime end,
  required double comparisonLine,
  required int maxPauseMinutes,
}) {
  if (!end.isAfter(start) || !comparisonLine.isFinite || maxPauseMinutes < 0) {
    throw ArgumentError('Invalid history export window or parameters');
  }
  final selectedMinutes = minutes.where((minute) {
    final stamp = DateTime.fromMillisecondsSinceEpoch(minute.timestamp * 1000,
        isUtc: true);
    return !stamp.isBefore(start) &&
        !stamp.add(const Duration(minutes: 1)).isAfter(end);
  }).toList();
  final selectedHints = hints
      .where((hint) => hint.end.isAfter(start) && hint.start.isBefore(end))
      .map((hint) => SourceHistoryEntry(
          id: hint.id,
          category: hint.category,
          start: hint.start.isBefore(start) ? start : hint.start,
          end: hint.end.isAfter(end) ? end : hint.end,
          confidence: hint.confidence,
          isCoverage: hint.isCoverage))
      .toList();
  final episodes = groupLevelHistory(selectedMinutes,
      threshold: comparisonLine, maxPauseMinutes: maxPauseMinutes)
    ..sort((a, b) => b.duration.compareTo(a.duration));
  return const JsonEncoder.withIndent('  ').convert({
    'schema': 'opennoisenet.private_history.v1',
    'window_start': start.toUtc().toIso8601String(),
    'window_end': end.toUtc().toIso8601String(),
    'analysis': {
      'comparison_line': comparisonLine,
      'max_pause_minutes': maxPauseMinutes,
      'semantics': 'temporal_grouping_not_proven_common_cause',
      'source_phase_algorithm': AcousticPhasePolicy.version,
    },
    'limitations': {
      'levels': 'uncalibrated_estimates; method_not_stored_per_minute',
      'sources': 'unverified_model_hints; missing_hints_do_not_mean_silence',
      'coverage': 'saved_minutes_do_not_prove_uninterrupted_capture',
    },
    'minutes': selectedMinutes
        .map((minute) => {
              'timestamp': minute.timestamp,
              'estimated_level': minute.leqDb,
              'highest_buffer_estimate': minute.lmaxDb,
              'samples_count': minute.samplesCount,
            })
        .toList(),
    'analysis_coverage': selectedHints
        .where((hint) => hint.isCoverage)
        .map((hint) => {
              'start_ms': hint.start.millisecondsSinceEpoch,
              'end_ms': hint.end.millisecondsSinceEpoch
            })
        .toList(),
    'acoustic_phases':
        sourcePhases(selectedHints).map((p) => p.toJson()).toList(),
    'source_hints': selectedHints
        .where((hint) => !hint.isCoverage)
        .map((hint) => {
              'start': hint.start.toUtc().toIso8601String(),
              'end': hint.end.toUtc().toIso8601String(),
              'category': hint.category,
              'confidence': hint.confidence,
            })
        .toList(),
    'episodes': episodes
        .map((episode) => {
              'start': episode.start.toUtc().toIso8601String(),
              'end': episode.end.toUtc().toIso8601String(),
              'active_minutes': episode.activeMinutes,
              'pause_minutes': episode.pauseMinutes,
              'pause_count': episode.pauseCount,
              'mean_estimate': episode.averageMinute,
              'highest_minute_estimate': episode.highestMinute,
              'source_coverage_ms':
                  sourceCoverage(episode, selectedHints).inMilliseconds,
            })
        .toList(),
  });
}
