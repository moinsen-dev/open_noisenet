import 'dart:math' as math;

/// Experimental streaming A-weighting of normalized PCM samples.
///
/// Matched-z pole mapping with a high-frequency correction zero, normalized to
/// 0 dB at 1 kHz. This is not an instrument certification: the microphone,
/// input processing and calibration remain unverified. Reset for a new stream.
/// Design follows https://pmc.ncbi.nlm.nih.gov/articles/PMC7865466/; the
/// correction coefficients were selected for our discrete sample rates by
/// minimizing maximum error at third-octave reference frequencies.
class AWeightingFilter {
  AWeightingFilter(int sampleRate) : _sections = _buildSections(sampleRate);

  final List<_Biquad> _sections;

  static List<_Biquad> _buildSections(int sampleRate) {
    if (sampleRate != 44100 && sampleRate != 48000) {
      throw ArgumentError.value(
          sampleRate, 'sampleRate', 'validated rates are 44100 and 48000 Hz');
    }
    double pole(double hz) => math.exp(-2 * math.pi * hz / sampleRate);

    final low = pole(20.598997);
    final middleLow = pole(107.65265);
    final middleHigh = pole(737.86223);
    final high = pole(12194.217);
    final sections = [
      _Biquad(1, -2, 1, -2 * low, low * low),
      _Biquad(1, -2, 1, -(middleLow + middleHigh), middleLow * middleHigh),
      _Biquad(
          1, sampleRate == 44100 ? 0.286 : 0.275, 0, -2 * high, high * high),
    ];
    final omega = 2 * math.pi * 1000 / sampleRate;
    final magnitude = sections.fold<double>(
        1, (product, section) => product * section.magnitudeAt(omega));
    sections.first.scaleNumerator(1 / magnitude);
    return sections;
  }

  /// Returns a new buffer, preserving filter state between adjacent buffers.
  List<double> process(List<double> samples) {
    if (samples.any((sample) => !sample.isFinite)) {
      throw ArgumentError('PCM samples must be finite');
    }
    return List<double>.generate(samples.length, (index) {
      var sample = samples[index];
      for (final section in _sections) {
        sample = section.process(sample);
      }
      return sample;
    }, growable: false);
  }

  void reset() {
    for (final section in _sections) {
      section.reset();
    }
  }
}

class _Biquad {
  _Biquad(this.b0, this.b1, this.b2, this.a1, this.a2);

  double b0, b1, b2;
  final double a1, a2;
  double _s1 = 0, _s2 = 0;

  void scaleNumerator(double factor) {
    b0 *= factor;
    b1 *= factor;
    b2 *= factor;
  }

  double process(double input) {
    final output = b0 * input + _s1;
    _s1 = b1 * input - a1 * output + _s2;
    _s2 = b2 * input - a2 * output;
    return output;
  }

  void reset() {
    _s1 = 0;
    _s2 = 0;
  }

  double magnitudeAt(double omega) {
    double magnitude(double c0, double c1, double c2) {
      final real = c0 + c1 * math.cos(omega) + c2 * math.cos(2 * omega);
      final imag = -c1 * math.sin(omega) - c2 * math.sin(2 * omega);
      return math.sqrt(real * real + imag * imag);
    }

    return magnitude(b0, b1, b2) / magnitude(1, a1, a2);
  }
}
