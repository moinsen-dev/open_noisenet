import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/sound_analysis/streaming_linear_resampler.dart';

void main() {
  test('resamples 48 kHz mono PCM to 16 kHz', () {
    final resampler = StreamingLinearResampler();
    final output = resampler.process(
      List<double>.filled(48000, 0.25),
      inputSampleRate: 48000,
    );

    expect(output, hasLength(16000));
    expect(output.every((sample) => (sample - 0.25).abs() < 1e-9), isTrue);
  });

  test('keeps fractional phase coherent across 44.1 kHz chunks', () {
    final resampler = StreamingLinearResampler();
    final first = resampler.process(
      List<double>.filled(22050, -0.4),
      inputSampleRate: 44100,
    );
    final second = resampler.process(
      List<double>.filled(22050, -0.4),
      inputSampleRate: 44100,
    );

    expect(first.length + second.length, closeTo(16000, 1));
    expect([...first, ...second].every((sample) => sample == -0.4), isTrue);
  });
}
