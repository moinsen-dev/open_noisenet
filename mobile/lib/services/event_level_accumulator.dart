import 'dart:collection';
import 'dart:math';

/// Aggregates each detected-event buffer once in the energy domain.
///
/// Buffer durations are assumed approximately equal; the recent sample tail
/// is bounded for classification and is not the complete event history.
class EventLevelAccumulator {
  EventLevelAccumulator({this.maxRecentSamples = 1000})
      : assert(maxRecentSamples > 0);

  final int maxRecentSamples;
  final Queue<double> _recent = Queue<double>();
  double _energySum = 0;
  int _count = 0;
  double? _min;
  double? _max;

  void add(double levelDb) {
    if (!levelDb.isFinite) {
      throw ArgumentError.value(levelDb, 'levelDb', 'must be finite');
    }
    _energySum += pow(10, levelDb / 10);
    _count++;
    _min = _min == null ? levelDb : min(_min!, levelDb);
    _max = _max == null ? levelDb : max(_max!, levelDb);
    _recent.addLast(levelDb);
    if (_recent.length > maxRecentSamples) _recent.removeFirst();
  }

  int get count => _count;
  double get averageDb => 10 * log(_energySum / _count) / ln10;
  double get minDb => _min!;
  double get maxDb => _max!;
  List<double> get recent => List.unmodifiable(_recent);
}
