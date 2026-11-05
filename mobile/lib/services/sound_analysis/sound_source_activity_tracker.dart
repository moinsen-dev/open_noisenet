import 'dart:collection';

import 'sound_analysis_models.dart';

/// Turns overlapping frame classifications into source-activity intervals.
///
/// Two agreeing frames activate a source. Three missing frames release it.
/// Category changes also need two agreeing frames. This filters isolated model
/// spikes while retaining roughly half-second boundary resolution.
class SoundSourceActivityTracker {
  static const version = 'yamnet_frame_hysteresis_v2';
  static const frameHopMilliseconds = 480;
  static const frameWindowMilliseconds = 975;

  final double activationConfidence;
  final int activationFrames;
  final int releaseFrames;
  final Duration retention;

  final Queue<SoundSourceSegment> _completed = Queue<SoundSourceSegment>();
  _SegmentAccumulator? _active;
  _SegmentAccumulator? _candidate;
  int _releaseFrameCount = 0;
  SoundSourceSegment? _lastCompleted;
  SoundSourceActivitySnapshot? _latestSnapshot;

  SoundSourceActivityTracker({
    this.activationConfidence = 0.18,
    this.activationFrames = 2,
    this.releaseFrames = 3,
    this.retention = const Duration(minutes: 30),
  })  : assert(activationFrames > 0),
        assert(releaseFrames > 0);

  SoundSourceActivitySnapshot? get latestSnapshot => _latestSnapshot;

  List<SoundSourceSegment> get completedSegments =>
      List<SoundSourceSegment>.unmodifiable(_completed);

  SoundSourceActivitySnapshot add(SoundClassificationFrame frame) {
    _prune(frame.windowEnd);
    final categoryMinimum =
        OpenNoiseClassificationPolicy.minimumConfidenceFor(frame.category);
    final requiredConfidence = activationConfidence > categoryMinimum
        ? activationConfidence
        : categoryMinimum;
    final hasSourceEvidence =
        frame.category != OpenNoiseCategory.unknownSoundSource &&
            frame.confidence >= requiredConfidence;

    if (_active == null) {
      _trackActivationCandidate(frame, hasSourceEvidence);
    } else if (hasSourceEvidence && frame.category == _active!.category) {
      _active!.add(frame);
      _candidate = null;
      _releaseFrameCount = 0;
    } else if (hasSourceEvidence) {
      _trackReplacementCandidate(frame);
    } else {
      _candidate = null;
      _releaseFrameCount++;
      if (_releaseFrameCount >= releaseFrames) {
        _completeActive();
      }
    }

    return _publish(frame);
  }

  /// Finalize evidence when monitoring stops, without extending the interval
  /// beyond the final frame that actually supported the category.
  SoundSourceActivitySnapshot? finish({DateTime? observedAt}) {
    if (_active == null && _latestSnapshot == null) return null;
    _completeActive();
    final snapshot = SoundSourceActivitySnapshot(
      observedAt: observedAt ?? DateTime.now(),
      latestCategory: OpenNoiseCategory.unknownSoundSource,
      latestConfidence: 0,
      activeSegment: null,
      lastCompletedSegment: _lastCompleted,
    );
    _latestSnapshot = snapshot;
    return snapshot;
  }

  List<SoundSourceSegment> segmentsOverlapping({
    required DateTime start,
    required DateTime end,
    bool includeActive = true,
  }) {
    if (!end.isAfter(start)) return const [];
    final segments = <SoundSourceSegment>[
      ..._completed.where((segment) => _overlaps(segment, start, end)),
    ];
    final active = _active?.toSegment();
    if (includeActive && active != null && _overlaps(active, start, end)) {
      segments.add(active);
    }
    segments.sort((left, right) => left.start.compareTo(right.start));
    return List<SoundSourceSegment>.unmodifiable(segments);
  }

  void clear() {
    _completed.clear();
    _active = null;
    _candidate = null;
    _releaseFrameCount = 0;
    _lastCompleted = null;
    _latestSnapshot = null;
  }

  void _trackActivationCandidate(
    SoundClassificationFrame frame,
    bool hasSourceEvidence,
  ) {
    if (!hasSourceEvidence) {
      _candidate = null;
      return;
    }

    if (_candidate?.category == frame.category) {
      _candidate!.add(frame);
    } else {
      _candidate = _SegmentAccumulator.fromFrame(frame);
    }

    if (_candidate!.frameCount >= activationFrames) {
      _active = _candidate;
      _candidate = null;
      _releaseFrameCount = 0;
    }
  }

  void _trackReplacementCandidate(SoundClassificationFrame frame) {
    _releaseFrameCount++;
    if (_candidate?.category == frame.category) {
      _candidate!.add(frame);
    } else {
      _candidate = _SegmentAccumulator.fromFrame(frame);
    }

    if (_candidate!.frameCount >= activationFrames) {
      _completeActive();
      _active = _candidate;
      _candidate = null;
      _releaseFrameCount = 0;
    } else if (_releaseFrameCount >= releaseFrames) {
      _completeActive();
    }
  }

  void _completeActive() {
    final active = _active;
    if (active != null) {
      final segment = active.toSegment();
      _completed.addLast(segment);
      _lastCompleted = segment;
    }
    _active = null;
    _releaseFrameCount = 0;
  }

  SoundSourceActivitySnapshot _publish(SoundClassificationFrame frame) {
    final active = _active?.toSegment();
    final snapshot = SoundSourceActivitySnapshot(
      observedAt: frame.windowEnd,
      // A single frame is only an internal candidate. Publish a source label
      // after it has passed both confidence and activation-frame gates.
      latestCategory: active?.category ?? OpenNoiseCategory.unknownSoundSource,
      latestConfidence: active?.confidence ?? 0,
      activeSegment: active,
      lastCompletedSegment: _lastCompleted,
    );
    _latestSnapshot = snapshot;
    return snapshot;
  }

  void _prune(DateTime now) {
    final cutoff = now.subtract(retention);
    while (_completed.isNotEmpty && _completed.first.end.isBefore(cutoff)) {
      final removed = _completed.removeFirst();
      if (identical(removed, _lastCompleted)) {
        _lastCompleted = _completed.isEmpty ? null : _completed.last;
      }
    }
  }

  bool _overlaps(
    SoundSourceSegment segment,
    DateTime start,
    DateTime end,
  ) =>
      segment.end.isAfter(start) && segment.start.isBefore(end);
}

class _SegmentAccumulator {
  final String category;
  final DateTime start;
  DateTime end;
  double _confidenceSum;
  int frameCount;
  final Map<String, double> _strongestScores;

  _SegmentAccumulator._({
    required this.category,
    required this.start,
    required this.end,
    required double confidenceSum,
    required this.frameCount,
    required Map<String, double> strongestScores,
  })  : _confidenceSum = confidenceSum,
        _strongestScores = strongestScores;

  factory _SegmentAccumulator.fromFrame(SoundClassificationFrame frame) {
    return _SegmentAccumulator._(
      category: frame.category,
      start: frame.windowStart,
      end: frame.windowEnd,
      confidenceSum: frame.confidence,
      frameCount: 1,
      strongestScores: {
        for (final score in frame.topYamnetScores) score.label: score.score,
      },
    );
  }

  void add(SoundClassificationFrame frame) {
    if (frame.windowEnd.isAfter(end)) end = frame.windowEnd;
    _confidenceSum += frame.confidence;
    frameCount++;
    for (final score in frame.topYamnetScores) {
      final existing = _strongestScores[score.label] ?? 0;
      if (score.score > existing) _strongestScores[score.label] = score.score;
    }
  }

  SoundSourceSegment toSegment() {
    final scores = _strongestScores.entries
        .map((entry) => RawSoundScore(label: entry.key, score: entry.value))
        .toList()
      ..sort((left, right) => right.score.compareTo(left.score));
    return SoundSourceSegment(
      start: start,
      end: end,
      category: category,
      confidence: _confidenceSum / frameCount,
      evidenceFrameCount: frameCount,
      strongestYamnetScores: List.unmodifiable(scores.take(5)),
      timingBasis: SoundSourceActivityTracker.version,
    );
  }
}
