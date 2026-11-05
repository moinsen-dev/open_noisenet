import 'dart:math';

/// Combine levels in the energy domain using comparable observation weights.
/// Returns null when there is no usable observation.
double? energyAverageDb(Iterable<(double, int)> observations) {
  var energySum = 0.0;
  var totalWeight = 0;
  for (final (level, weight) in observations) {
    if (!level.isFinite || weight <= 0) continue;
    energySum += pow(10, level / 10) * weight;
    totalWeight += weight;
  }
  if (totalWeight == 0 || !energySum.isFinite || energySum <= 0) return null;
  return 10 * log(energySum / totalWeight) / ln10;
}

/// Highest energy average over 15 consecutive, timestamped minute records.
/// A missing or duplicated minute cannot form a complete window.
double? highestQuarterHourEstimate(Iterable<(int, double)> observations) {
  final sorted = observations.toList()..sort((a, b) => a.$1.compareTo(b.$1));
  double? highest;
  for (var end = 14; end < sorted.length; end++) {
    final start = end - 14;
    var consecutive = true;
    for (var i = start + 1; i <= end; i++) {
      if (sorted[i].$1 - sorted[i - 1].$1 != 60) {
        consecutive = false;
        break;
      }
    }
    if (!consecutive) continue;
    final average = energyAverageDb(
        sorted.getRange(start, end + 1).map((point) => (point.$2, 1)));
    if (average != null && (highest == null || average > highest)) {
      highest = average;
    }
  }
  return highest;
}
