/// Stateful mono resampler for the microphone stream.
///
/// Linear interpolation is sufficient here because YAMNet is the consumer,
/// not an archival audio path. State is retained across chunks so 44.1 kHz
/// iOS input does not accumulate boundary gaps when converted to 16 kHz.
class StreamingLinearResampler {
  final int outputSampleRate;

  int? _inputSampleRate;
  final List<double> _source = <double>[];
  double _sourcePosition = 0;

  StreamingLinearResampler({this.outputSampleRate = 16000});

  List<double> process(List<double> input, {required int inputSampleRate}) {
    if (input.isEmpty) return const [];
    if (inputSampleRate <= 0 || outputSampleRate <= 0) {
      throw ArgumentError('Sample rates must be positive.');
    }

    if (_inputSampleRate != inputSampleRate) {
      reset();
      _inputSampleRate = inputSampleRate;
    }

    if (inputSampleRate == outputSampleRate && _source.isEmpty) {
      return List<double>.from(input, growable: false);
    }

    _source.addAll(input);
    final step = inputSampleRate / outputSampleRate;
    final output = <double>[];

    while (_sourcePosition + 1 < _source.length) {
      final lower = _sourcePosition.floor();
      final fraction = _sourcePosition - lower;
      final a = _source[lower];
      final b = _source[lower + 1];
      output.add(a + ((b - a) * fraction));
      _sourcePosition += step;
    }

    final consumed = _sourcePosition.floor();
    if (consumed > 0) {
      _source.removeRange(0, consumed.clamp(0, _source.length));
      _sourcePosition -= consumed;
    }

    return output;
  }

  void reset() {
    _source.clear();
    _sourcePosition = 0;
    _inputSampleRate = null;
  }
}
