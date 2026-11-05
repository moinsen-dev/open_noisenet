import 'dart:math';

/// An unweighted digital level estimate, not a calibrated pressure in pascals.
///
/// The 16-bit scale keeps the existing app's relative level convention. A
/// reference-meter offset can align one operating point, but cannot establish
/// frequency weighting or sound-meter compliance.
double? bufferLevelDb(List<double> samples, {double offsetDb = 0}) {
  if (samples.isEmpty || !offsetDb.isFinite) return null;
  var sumSquares = 0.0;
  for (final sample in samples) {
    if (!sample.isFinite) return null;
    sumSquares += sample * sample;
  }
  final rms = sqrt(sumSquares / samples.length);
  if (rms == 0) return 10;
  final level = 20 * log(32768 * rms) / ln10 + offsetDb;
  if (!level.isFinite) return null;
  return level.clamp(10.0, 140.0);
}
