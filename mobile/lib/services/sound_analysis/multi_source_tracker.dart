import 'sound_analysis_models.dart';
import 'sound_source_activity_tracker.dart';

/// Keep independently supported categories instead of only the winning label.
/// No extra audio buffering, speaker identification or transcription.
class MultiSourceTracker {
  final Map<String, SoundSourceActivityTracker> _tracks = {};
  DateTime? _lastEnd;

  List<SoundSourceActivitySnapshot> add(SoundClassificationFrame frame) {
    final result = <SoundSourceActivitySnapshot>[];
    if (_lastEnd != null && frame.windowStart.isAfter(_lastEnd!)) {
      result.addAll(finish());
    }
    _lastEnd = frame.windowEnd;
    for (final category in OpenNoiseCategory.values) {
      if (category == OpenNoiseCategory.unknownSoundSource) continue;
      final score = frame.categoryScores[category] ?? 0;
      final track = _tracks.putIfAbsent(
          category, () => SoundSourceActivityTracker(retention: Duration.zero));
      result.add(track.add(SoundClassificationFrame(
        windowStart: frame.windowStart,
        windowEnd: frame.windowEnd,
        category: score.isFinite &&
                OpenNoiseClassificationPolicy.accepts(category, score)
            ? category
            : OpenNoiseCategory.unknownSoundSource,
        confidence: score.isFinite ? score : 0,
        categoryScores: const {},
        topYamnetScores: const [],
        inferenceMs: frame.inferenceMs,
      )));
    }
    return result;
  }

  List<SoundSourceActivitySnapshot> finish() {
    final results = <SoundSourceActivitySnapshot>[];
    for (final track in _tracks.values) {
      final result = track.finish();
      if (result != null) results.add(result);
    }
    _tracks.clear();
    _lastEnd = null;
    return results;
  }
}
