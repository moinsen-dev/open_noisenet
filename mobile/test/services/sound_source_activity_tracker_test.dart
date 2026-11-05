import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/sound_analysis/sound_analysis_models.dart';
import 'package:noisenet_mobile/services/sound_analysis/sound_source_activity_tracker.dart';

void main() {
  final origin = DateTime.utc(2026, 8, 18, 18);

  test('measures a stable source independently of the rolling Leq window', () {
    final tracker = SoundSourceActivityTracker();

    tracker.add(_frame(origin, 0, OpenNoiseCategory.roadTraffic, 0.72));
    final started = tracker.add(
      _frame(origin, 480, OpenNoiseCategory.roadTraffic, 0.76),
    );
    final extended = tracker.add(
      _frame(origin, 960, OpenNoiseCategory.roadTraffic, 0.74),
    );

    expect(started.activeSegment, isNotNull);
    expect(started.activeSegment!.start, origin);
    expect(extended.activeSegment!.duration.inMilliseconds, 1935);

    tracker.add(
      _frame(origin, 1440, OpenNoiseCategory.unknownSoundSource, 0.08),
    );
    tracker.add(
      _frame(origin, 1920, OpenNoiseCategory.unknownSoundSource, 0.07),
    );
    final stopped = tracker.add(
      _frame(origin, 2400, OpenNoiseCategory.unknownSoundSource, 0.06),
    );

    expect(stopped.activeSegment, isNull);
    expect(stopped.lastCompletedSegment, isNotNull);
    expect(
      stopped.lastCompletedSegment!.category,
      OpenNoiseCategory.roadTraffic,
    );
    expect(stopped.lastCompletedSegment!.duration.inMilliseconds, 1935);
    expect(stopped.lastCompletedSegment!.evidenceFrameCount, 3);
  });

  test('does not turn one uncertain frame into a source interval', () {
    final tracker = SoundSourceActivityTracker();

    final candidate = tracker.add(
      _frame(origin, 0, OpenNoiseCategory.drilling, 0.7),
    );
    final cleared = tracker.add(
      _frame(origin, 480, OpenNoiseCategory.unknownSoundSource, 0.05),
    );

    expect(candidate.activeSegment, isNull);
    expect(cleared.activeSegment, isNull);
    expect(tracker.completedSegments, isEmpty);
  });

  test('does not expose the observed weak animal frame as an animal source',
      () {
    final tracker = SoundSourceActivityTracker();

    final snapshot = tracker.add(
      _frame(origin, 0, OpenNoiseCategory.animals, 0.1201171875),
    );

    expect(snapshot.latestCategory, OpenNoiseCategory.unknownSoundSource);
    expect(snapshot.activeSegment, isNull);
  });

  test('requires a stable replacement before switching source category', () {
    final tracker = SoundSourceActivityTracker();

    tracker.add(_frame(origin, 0, OpenNoiseCategory.roadTraffic, 0.8));
    tracker.add(_frame(origin, 480, OpenNoiseCategory.roadTraffic, 0.8));
    final oneDrill = tracker.add(
      _frame(origin, 960, OpenNoiseCategory.drilling, 0.75),
    );
    final switched = tracker.add(
      _frame(origin, 1440, OpenNoiseCategory.drilling, 0.78),
    );

    expect(oneDrill.activeSegment!.category, OpenNoiseCategory.roadTraffic);
    expect(switched.activeSegment!.category, OpenNoiseCategory.drilling);
    expect(switched.activeSegment!.start,
        origin.add(const Duration(milliseconds: 960)));
    expect(
      switched.lastCompletedSegment!.category,
      OpenNoiseCategory.roadTraffic,
    );
  });

  test('exports structured overlapping intervals without waveform data', () {
    final tracker = SoundSourceActivityTracker();

    tracker.add(_frame(origin, 0, OpenNoiseCategory.animals, 0.7));
    tracker.add(_frame(origin, 480, OpenNoiseCategory.animals, 0.8));

    final segments = tracker.segmentsOverlapping(
      start: origin.subtract(const Duration(seconds: 1)),
      end: origin.add(const Duration(seconds: 5)),
    );
    final metadata = segments.single.toJson();

    expect(metadata['category'], OpenNoiseCategory.animals);
    expect(metadata['duration_ms'], 1455);
    expect(metadata['timing_basis'], SoundSourceActivityTracker.version);
    expect(metadata, isNot(contains('samples')));
    expect(metadata, isNot(contains('waveform')));
  });

  test('finishing clears the live label but preserves the completed interval',
      () {
    final tracker = SoundSourceActivityTracker();
    tracker.add(_frame(origin, 0, OpenNoiseCategory.animals, 0.7));
    tracker.add(_frame(origin, 480, OpenNoiseCategory.animals, 0.8));

    final finished =
        tracker.finish(observedAt: origin.add(const Duration(seconds: 2)));

    expect(finished, isNotNull);
    expect(finished!.latestCategory, OpenNoiseCategory.unknownSoundSource);
    expect(finished.latestConfidence, 0);
    expect(finished.activeSegment, isNull);
    expect(finished.lastCompletedSegment!.category, OpenNoiseCategory.animals);
  });
}

SoundClassificationFrame _frame(
  DateTime origin,
  int startMs,
  String category,
  double confidence,
) {
  final start = origin.add(Duration(milliseconds: startMs));
  return SoundClassificationFrame(
    windowStart: start,
    windowEnd: start.add(const Duration(milliseconds: 975)),
    category: category,
    confidence: confidence,
    categoryScores: {category: confidence},
    topYamnetScores: [
      RawSoundScore(label: category, score: confidence),
    ],
    inferenceMs: 12,
  );
}
