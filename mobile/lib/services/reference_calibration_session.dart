import 'dart:math' as math;

import 'sound_analysis/sound_analysis_models.dart';

/// Accumulates PCM energy in memory only; no raw samples are retained.
class ReferenceCalibrationSession {
  ReferenceCalibrationSession({this.duration = const Duration(seconds: 60)}) {
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'must be positive');
    }
  }

  final Duration duration;
  int? _sampleRate;
  DateTime? _firstFrameAt;
  DateTime? _lastFrameAt;
  int _firstFrameSamples = 0;
  int _sampleCount = 0;
  int _clippedSamples = 0;
  double _sumSquares = 0;
  String? _error;

  String? get error => _error;
  double get elapsedSeconds =>
      _sampleRate == null ? 0 : _sampleCount / _sampleRate!;
  bool get isComplete =>
      _error == null && elapsedSeconds >= duration.inMicroseconds / 1e6;

  void addFrame(PcmAudioFrame frame) {
    if (_error != null || isComplete || frame.samples.isEmpty) return;
    if (frame.sampleRate <= 0 ||
        (_sampleRate != null && frame.sampleRate != _sampleRate)) {
      _error = 'Microphone sample rate changed during the comparison.';
      return;
    }
    if (_lastFrameAt != null) {
      final gap = frame.capturedAt.difference(_lastFrameAt!);
      if (gap.isNegative || gap > const Duration(seconds: 2)) {
        _error = 'Microphone data was interrupted during the comparison.';
        return;
      }
    }
    if (frame.samples.any((sample) => !sample.isFinite || sample.abs() > 1)) {
      _error = 'Microphone returned invalid samples.';
      return;
    }
    _sampleRate ??= frame.sampleRate;
    _firstFrameAt ??= frame.capturedAt;
    _lastFrameAt = frame.capturedAt;
    final target = (duration.inMicroseconds * _sampleRate! / 1e6).ceil();
    final remaining = target - _sampleCount;
    final before = _sampleCount;
    for (final sample in frame.samples.take(remaining)) {
      _sumSquares += sample * sample;
      if (sample.abs() >= 0.98) _clippedSamples++;
      _sampleCount++;
    }
    if (before == 0) _firstFrameSamples = _sampleCount;
    final wallSeconds =
        frame.capturedAt.difference(_firstFrameAt!).inMicroseconds / 1e6;
    final audioSeconds = (_sampleCount - _firstFrameSamples) / _sampleRate!;
    if ((wallSeconds - audioSeconds).abs() > 2) {
      _error = 'Microphone samples do not cover the comparison interval.';
    }
  }

  /// Offset for a simultaneous, unweighted LZeq reference reading.
  double? offsetForReference(double referenceDb) {
    if (!isComplete ||
        !referenceDb.isFinite ||
        referenceDb < 0 ||
        referenceDb > 140 ||
        _sumSquares <= 0 ||
        _clippedSamples / _sampleCount > 0.001) {
      return null;
    }
    final rawRms = math.sqrt(_sumSquares / _sampleCount);
    final rawDb = 20 * math.log(32768 * rawRms) / math.ln10;
    return referenceDb - rawDb;
  }
}
