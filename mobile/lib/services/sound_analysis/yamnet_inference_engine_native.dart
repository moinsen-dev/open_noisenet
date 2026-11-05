import 'package:tflite_flutter/tflite_flutter.dart';

import 'yamnet_inference_engine.dart';

YamnetInferenceEngine createYamnetInferenceEngine() =>
    NativeYamnetInferenceEngine();

class NativeYamnetInferenceEngine implements YamnetInferenceEngine {
  static const modelAsset = 'assets/models/yamnet.tflite';
  static const expectedInputSamples = 15600;
  static const expectedOutputClasses = 521;

  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;

  @override
  bool get isReady => _interpreter != null && _isolateInterpreter != null;

  @override
  String get modelVersion => 'yamnet_float32_mediapipe_latest';

  @override
  Future<void> initialize() async {
    if (isReady) return;

    final options = InterpreterOptions()..threads = 2;
    final interpreter = await Interpreter.fromAsset(
      modelAsset,
      options: options,
    );
    final input = interpreter.getInputTensor(0);
    final output = interpreter.getOutputTensor(0);
    if (input.numElements() != expectedInputSamples) {
      interpreter.close();
      throw StateError(
        'Unexpected YAMNet input shape ${input.shape}; '
        'expected $expectedInputSamples samples.',
      );
    }
    if (output.numElements() != expectedOutputClasses) {
      interpreter.close();
      throw StateError(
        'Unexpected YAMNet output shape ${output.shape}; '
        'expected $expectedOutputClasses scores.',
      );
    }

    final isolate = await IsolateInterpreter.create(
      address: interpreter.address,
      debugName: 'OpenNoiseNetYamnet',
    );
    _interpreter = interpreter;
    _isolateInterpreter = isolate;
  }

  @override
  Future<List<double>> run(List<double> waveform) async {
    if (!isReady) {
      throw StateError('YAMNet inference is not initialized.');
    }
    if (waveform.length != expectedInputSamples) {
      throw ArgumentError.value(
        waveform.length,
        'waveform.length',
        'YAMNet requires exactly $expectedInputSamples mono samples.',
      );
    }

    final output = <List<double>>[
      List<double>.filled(expectedOutputClasses, 0),
    ];
    await _isolateInterpreter!.run(List<double>.from(waveform), output);
    return List<double>.unmodifiable(output.first);
  }

  @override
  Future<void> close() async {
    await _isolateInterpreter?.close();
    _isolateInterpreter = null;
    _interpreter?.close();
    _interpreter = null;
  }
}
