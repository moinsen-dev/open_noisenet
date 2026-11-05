import 'yamnet_inference_engine_stub.dart'
    if (dart.library.io) 'yamnet_inference_engine_native.dart'
    as implementation;

abstract interface class YamnetInferenceEngine {
  bool get isReady;
  String get modelVersion;

  Future<void> initialize();
  Future<List<double>> run(List<double> waveform);
  Future<void> close();
}

YamnetInferenceEngine createYamnetInferenceEngine() =>
    implementation.createYamnetInferenceEngine();
