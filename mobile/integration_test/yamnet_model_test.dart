import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noisenet_mobile/services/sound_analysis/yamnet_inference_engine_native.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bundled YAMNet model honors the device tensor contract',
      (tester) async {
    final engine = NativeYamnetInferenceEngine();
    addTearDown(engine.close);

    await engine.initialize();
    final scores = await engine.run(
      List<double>.filled(NativeYamnetInferenceEngine.expectedInputSamples, 0),
    );

    expect(engine.isReady, isTrue);
    expect(
      scores,
      hasLength(NativeYamnetInferenceEngine.expectedOutputClasses),
    );
    expect(scores.every((score) => score.isFinite), isTrue);
  });
}
