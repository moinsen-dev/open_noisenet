import 'dart:collection';

import 'audio_processing_service.dart';

/// Keeps timestamped level estimates for a rolling time window.
///
/// A safety cap bounds memory if an audio source sends unexpectedly small
/// buffers; normal microphone buffer rates retain the full 15-minute window.
class LevelHistory {
  LevelHistory({
    this.window = const Duration(minutes: 15),
    this.maxSamples = 90000,
  }) : assert(maxSamples > 0);

  final Duration window;
  final int maxSamples;
  final Queue<TimestampedSPL> _samples = Queue<TimestampedSPL>();

  void add(TimestampedSPL sample) {
    final cutoff = sample.timestamp.subtract(window);
    while (_samples.isNotEmpty && _samples.first.timestamp.isBefore(cutoff)) {
      _samples.removeFirst();
    }
    _samples.addLast(sample);
    while (_samples.length > maxSamples) {
      _samples.removeFirst();
    }
  }

  bool get isEmpty => _samples.isEmpty;
  TimestampedSPL get last => _samples.last;
  List<TimestampedSPL> get samples => List.unmodifiable(_samples);
}
