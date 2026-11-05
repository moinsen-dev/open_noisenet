// Offline JSON adapter: the benchmark uses the exact app interval engine.
import 'dart:convert';
import 'dart:io';

import '../mobile/lib/services/sound_analysis/acoustic_phase.dart';
import '../mobile/lib/services/sound_analysis/multi_source_tracker.dart';
import '../mobile/lib/services/sound_analysis/sound_analysis_models.dart';
import '../mobile/lib/services/sound_analysis/open_noise_taxonomy_head.dart';

Future<void> main() async {
  final input = jsonDecode(
    await stdin.transform(utf8.decoder).join(),
  ) as Map<String, dynamic>;
  final output = <Map<String, dynamic>>[];
  for (final scene in (input['scenes'] ?? []) as List) {
    final evidence = <AcousticEvidence>[];
    final coverage = <AcousticInterval>[];
    final completed = <String>{};
    final tracker = MultiSourceTracker();
    void record(Iterable<SoundSourceActivitySnapshot> snapshots) {
      for (final snapshot in snapshots) {
        final segment = snapshot.lastCompletedSegment;
        if (segment == null) continue;
        final key =
            '${segment.category}:${segment.start.millisecondsSinceEpoch}';
        if (completed.add(key))
          evidence.add(
            AcousticEvidence(
              segment.start.millisecondsSinceEpoch,
              segment.end.millisecondsSinceEpoch,
              segment.category,
            ),
          );
      }
    }

    for (final row in scene['frames'] as List) {
      final start = row['start_ms'] as int, end = row['end_ms'] as int;
      final Map<String, double> scores;
      if (row['yamnet'] != null) {
        scores = OpenNoiseTaxonomyHead()
            .classify(
              yamnetScores: (row['yamnet'] as List)
                  .map((v) => (v as num).toDouble())
                  .toList(),
              labels: (input['labels'] as List).cast<String>(),
            )
            .scores;
      } else {
        scores = (row['scores'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        );
      }
      coverage.add(AcousticInterval(start, end));
      record(
        tracker.add(
          SoundClassificationFrame(
            windowStart: DateTime.fromMillisecondsSinceEpoch(
              start,
              isUtc: true,
            ),
            windowEnd: DateTime.fromMillisecondsSinceEpoch(end, isUtc: true),
            category: 'unknown_sound_source',
            confidence: 0,
            categoryScores: scores,
            topYamnetScores: const [],
            inferenceMs: 0,
          ),
        ),
      );
    }
    record(tracker.finish());
    final phases = buildAcousticPhases(evidence: evidence, coverage: coverage);
    output.add({
      'id': scene['id'],
      'phases': phases.map((p) => p.toJson()).toList(),
      'source_segment_count': evidence.length,
    });
  }
  final classifications = <Map<String, Object?>>[];
  for (final clip in (input['clips'] ?? []) as List) {
    final result = OpenNoiseTaxonomyHead().classify(
        yamnetScores: (clip['yamnet'] as List).map((v) => (v as num).toDouble()).toList(),
        labels: (input['labels'] as List).cast<String>());
    classifications.add({'id': clip['id'], 'category': result.category,
      'family': acousticFamily(result.category), 'scores': result.scores});
  }
  stdout.writeln(jsonEncode({'algorithm': AcousticPhasePolicy.version,
    'scenes': output, 'classifications': classifications}));
}
