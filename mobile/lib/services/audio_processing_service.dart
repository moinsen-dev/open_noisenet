import 'dart:math';
import 'dart:typed_data';

import '../core/logging/app_logger.dart';

/// Enhanced audio processing service with proper A-weighting implementation
class AudioProcessingService {
  static final AudioProcessingService _instance = AudioProcessingService._internal();
  factory AudioProcessingService() => _instance;
  AudioProcessingService._internal();

  /// A-weighting filter coefficients for standard frequencies
  /// Based on IEC 61672-1 standard for sound level meters
  static final Map<double, double> _aWeightingTable = {
    10.0: -70.4,
    12.5: -63.4,
    16.0: -56.7,
    20.0: -50.5,
    25.0: -44.7,
    31.5: -39.4,
    40.0: -34.6,
    50.0: -30.2,
    63.0: -26.2,
    80.0: -22.5,
    100.0: -19.1,
    125.0: -16.1,
    160.0: -13.4,
    200.0: -10.9,
    250.0: -8.6,
    315.0: -6.6,
    400.0: -4.8,
    500.0: -3.2,
    630.0: -1.9,
    800.0: -0.8,
    1000.0: 0.0,  // Reference frequency
    1250.0: 0.6,
    1600.0: 1.0,
    2000.0: 1.2,
    2500.0: 1.3,
    3150.0: 1.2,
    4000.0: 1.0,
    5000.0: 0.5,
    6300.0: -0.1,
    8000.0: -1.1,
    10000.0: -2.5,
    12500.0: -4.3,
    16000.0: -6.6,
    20000.0: -9.3,
  };

  /// Calculate A-weighted sound pressure level from raw audio data
  double calculateAWeightedSPL(Float32List audioSamples, double sampleRate) {
    try {
      // Calculate RMS (Root Mean Square) of the audio signal
      final rms = _calculateRMS(audioSamples);
      if (rms == 0.0) return 0.0;

      // Convert RMS to dB SPL
      // Reference: 20 µPa (threshold of hearing)
      final dbSPL = 20 * log(rms / 2e-5) / ln10;

      // Apply A-weighting compensation
      // For broadband signals, we use an approximate A-weighting factor
      final aWeightedSPL = dbSPL + _getBroadbandAWeighting(sampleRate);

      // Clamp to realistic range
      return aWeightedSPL.clamp(10.0, 140.0);

    } catch (e) {
      AppLogger.audio('Error calculating A-weighted SPL: $e');
      return 0.0;
    }
  }

  /// Calculate RMS (Root Mean Square) of audio samples
  double _calculateRMS(Float32List samples) {
    if (samples.isEmpty) return 0.0;

    double sumSquares = 0.0;
    for (final sample in samples) {
      sumSquares += sample * sample;
    }

    return sqrt(sumSquares / samples.length);
  }

  /// Get approximate A-weighting for broadband signals
  /// This is a simplified approach for real-time processing
  double _getBroadbandAWeighting(double sampleRate) {
    // For typical environmental noise (broadband), apply approximate A-weighting
    // This accounts for the human ear's frequency sensitivity

    if (sampleRate >= 44100) {
      // High sample rate - full frequency range
      return -2.0; // Approximate A-weighting for broadband environmental noise
    } else if (sampleRate >= 22050) {
      // Medium sample rate
      return -1.5;
    } else {
      // Lower sample rate - limited high frequency response
      return -1.0;
    }
  }

  /// Calculate equivalent continuous sound level (Leq) over time period
  double calculateLeq(List<double> splSamples, {Duration? timeWindow}) {
    if (splSamples.isEmpty) return 0.0;

    try {
      // Convert dB values to energy (power)
      double energySum = 0.0;
      for (final splDb in splSamples) {
        final energy = pow(10, splDb / 10);
        energySum += energy;
      }

      // Calculate mean energy and convert back to dB
      final meanEnergy = energySum / splSamples.length;
      final leq = 10 * log(meanEnergy) / ln10;

      return leq.clamp(10.0, 140.0);

    } catch (e) {
      AppLogger.audio('Error calculating Leq: $e');
      return splSamples.isNotEmpty ? splSamples.first : 0.0;
    }
  }

  /// Calculate Leq over 15-minute window (Leq15) as used in noise regulations
  double calculateLeq15(List<TimestampedSPL> measurements) {
    if (measurements.isEmpty) return 0.0;

    // Filter to last 15 minutes
    final now = DateTime.now();
    final fifteenMinutesAgo = now.subtract(const Duration(minutes: 15));

    final recentMeasurements = measurements
        .where((m) => m.timestamp.isAfter(fifteenMinutesAgo))
        .map((m) => m.splDb)
        .toList();

    return calculateLeq(recentMeasurements);
  }

  /// Apply frequency-specific A-weighting (for FFT-based analysis)
  Float32List applyAWeightingToSpectrum(Float32List magnitudes, List<double> frequencies) {
    final aWeighted = Float32List(magnitudes.length);

    for (int i = 0; i < magnitudes.length; i++) {
      final frequency = frequencies[i];
      final aWeight = _getAWeightingForFrequency(frequency);

      // Apply A-weighting in linear domain
      final aWeightLinear = pow(10, aWeight / 20);
      aWeighted[i] = magnitudes[i] * aWeightLinear;
    }

    return aWeighted;
  }

  /// Get A-weighting value for specific frequency
  double _getAWeightingForFrequency(double frequency) {
    // Find closest frequency in the A-weighting table
    double closestFreq = 1000.0;
    double minDiff = double.infinity;

    for (final freq in _aWeightingTable.keys) {
      final diff = (freq - frequency).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestFreq = freq;
      }
    }

    return _aWeightingTable[closestFreq] ?? 0.0;
  }

  /// Calculate statistical noise metrics
  NoiseStatistics calculateNoiseStatistics(List<double> splValues) {
    if (splValues.isEmpty) {
      return NoiseStatistics.empty();
    }

    final sorted = List<double>.from(splValues)..sort();
    final count = sorted.length;

    return NoiseStatistics(
      leq: calculateLeq(splValues),
      lmin: sorted.first,
      lmax: sorted.last,
      l10: _getPercentile(sorted, 0.10), // Exceeded 10% of time
      l50: _getPercentile(sorted, 0.50), // Median
      l90: _getPercentile(sorted, 0.90), // Exceeded 90% of time
      l95: _getPercentile(sorted, 0.95), // Exceeded 95% of time
      l99: _getPercentile(sorted, 0.99), // Exceeded 99% of time
      sampleCount: count,
      timeWindow: Duration(seconds: count), // Assuming 1 sample per second
    );
  }

  /// Get percentile value from sorted array
  double _getPercentile(List<double> sortedValues, double percentile) {
    if (sortedValues.isEmpty) return 0.0;

    final index = (sortedValues.length * (1.0 - percentile)).round();
    final clampedIndex = index.clamp(0, sortedValues.length - 1);
    return sortedValues[clampedIndex];
  }

  /// Detect noise events based on threshold exceedance
  bool detectNoiseEvent({
    required double currentSPL,
    required double thresholdDb,
    required Duration minDuration,
    required List<TimestampedSPL> recentMeasurements,
  }) {
    // Check if current level exceeds threshold
    if (currentSPL < thresholdDb) return false;

    // Check if exceedance has persisted for minimum duration
    final now = DateTime.now();
    final startTime = now.subtract(minDuration);

    final exceedingSamples = recentMeasurements
        .where((m) => m.timestamp.isAfter(startTime) && m.splDb >= thresholdDb)
        .length;

    final totalSamples = recentMeasurements
        .where((m) => m.timestamp.isAfter(startTime))
        .length;

    // Event detected if >80% of samples in time window exceed threshold
    return totalSamples > 0 && (exceedingSamples / totalSamples) > 0.8;
  }

  /// Get noise level category based on SPL
  NoiseLevel getNoiseLevel(double splDb) {
    if (splDb < 35) return NoiseLevel.veryQuiet;
    if (splDb < 50) return NoiseLevel.quiet;
    if (splDb < 55) return NoiseLevel.moderate;
    if (splDb < 65) return NoiseLevel.loud;
    if (splDb < 75) return NoiseLevel.veryLoud;
    if (splDb < 85) return NoiseLevel.harmful;
    return NoiseLevel.dangerous;
  }

  /// Get WHO/EPA compliance status
  ComplianceStatus getComplianceStatus(double leq, TimeOfDay timeOfDay) {
    // WHO Environmental Noise Guidelines 2018
    double limit;
    switch (timeOfDay) {
      case TimeOfDay.day:
        limit = 55.0; // Day time limit
        break;
      case TimeOfDay.evening:
        limit = 50.0; // Evening limit
        break;
      case TimeOfDay.night:
        limit = 40.0; // Night time limit
        break;
    }

    final exceedance = leq - limit;

    if (exceedance <= 0) return ComplianceStatus.compliant;
    if (exceedance <= 5) return ComplianceStatus.marginal;
    if (exceedance <= 10) return ComplianceStatus.violation;
    return ComplianceStatus.severe;
  }
}

/// Timestamped SPL measurement
class TimestampedSPL {
  final DateTime timestamp;
  final double splDb;

  const TimestampedSPL({
    required this.timestamp,
    required this.splDb,
  });
}

/// Comprehensive noise statistics
class NoiseStatistics {
  final double leq;    // Equivalent continuous sound level
  final double lmin;   // Minimum level
  final double lmax;   // Maximum level
  final double l10;    // Level exceeded 10% of time
  final double l50;    // Median level
  final double l90;    // Level exceeded 90% of time
  final double l95;    // Level exceeded 95% of time
  final double l99;    // Level exceeded 99% of time
  final int sampleCount;
  final Duration timeWindow;

  const NoiseStatistics({
    required this.leq,
    required this.lmin,
    required this.lmax,
    required this.l10,
    required this.l50,
    required this.l90,
    required this.l95,
    required this.l99,
    required this.sampleCount,
    required this.timeWindow,
  });

  factory NoiseStatistics.empty() {
    return const NoiseStatistics(
      leq: 0.0,
      lmin: 0.0,
      lmax: 0.0,
      l10: 0.0,
      l50: 0.0,
      l90: 0.0,
      l95: 0.0,
      l99: 0.0,
      sampleCount: 0,
      timeWindow: Duration.zero,
    );
  }
}

/// Noise level categories
enum NoiseLevel {
  veryQuiet,
  quiet,
  moderate,
  loud,
  veryLoud,
  harmful,
  dangerous,
}

/// Time of day for regulatory compliance
enum TimeOfDay { day, evening, night }

/// Compliance status with noise regulations
enum ComplianceStatus {
  compliant,
  marginal,
  violation,
  severe,
}
