import 'dart:math';

import 'sound_analysis_models.dart';

class SoundSceneAggregator {
  const SoundSceneAggregator();

  SoundSceneSummary? summarize({
    required Iterable<SoundClassificationFrame> frames,
    required DateTime start,
    required DateTime end,
  }) {
    final overlapping = frames
        .where((frame) =>
            !frame.windowEnd.isBefore(start) && !frame.windowStart.isAfter(end))
        .toList();
    if (overlapping.isEmpty) return null;

    final aggregateScores = <String, double>{};
    for (final category in OpenNoiseCategory.values) {
      if (category == OpenNoiseCategory.unknownSoundSource) continue;
      final values = overlapping
          .map((frame) => frame.categoryScores[category] ?? 0.0)
          .toList()
        ..sort((a, b) => b.compareTo(a));
      final focusCount = max(1, (values.length * 0.35).ceil());
      final focusedMean =
          values.take(focusCount).reduce((a, b) => a + b) / focusCount;
      final minimumConfidence =
          OpenNoiseClassificationPolicy.minimumConfidenceFor(category);
      final occupancy =
          values.where((value) => value >= minimumConfidence).length /
              values.length;
      aggregateScores[category] = ((focusedMean * 0.75) + (occupancy * 0.25))
          .clamp(0.0, 1.0)
          .toDouble();
    }

    final ranked = aggregateScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = ranked.first;
    final category = OpenNoiseClassificationPolicy.accepts(
      best.key,
      best.value,
    )
        ? best.key
        : OpenNoiseCategory.unknownSoundSource;
    final confidence = category == OpenNoiseCategory.unknownSoundSource
        ? (0.5 - best.value).clamp(0.15, 0.5).toDouble()
        : best.value;

    final rawByLabel = <String, double>{};
    for (final frame in overlapping) {
      for (final score in frame.topYamnetScores) {
        rawByLabel[score.label] =
            max(rawByLabel[score.label] ?? 0, score.score);
      }
    }
    final strongestRaw = rawByLabel.entries
        .map((entry) => RawSoundScore(label: entry.key, score: entry.value))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return SoundSceneSummary(
      start: start,
      end: end,
      category: category,
      confidence: confidence,
      frameCount: overlapping.length,
      categoryScores: Map.unmodifiable(aggregateScores),
      strongestYamnetScores: List.unmodifiable(strongestRaw.take(5)),
    );
  }
}
