import 'yamnet_inference_engine.dart';

YamnetInferenceEngine createYamnetInferenceEngine() =>
    _UnsupportedYamnetInferenceEngine();

class _UnsupportedYamnetInferenceEngine implements YamnetInferenceEngine {
  @override
  bool get isReady => false;

  @override
  String get modelVersion => 'yamnet_unavailable';

  @override
  Future<void> initialize() async {
    throw UnsupportedError(
      'YAMNet inference is only available in native app builds.',
    );
  }

  @override
  Future<List<double>> run(List<double> waveform) async {
    throw StateError('YAMNet inference is not initialized.');
  }

  @override
  Future<void> close() async {}
}
