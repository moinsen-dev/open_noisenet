import 'dart:async';

import 'package:audio_streamer/audio_streamer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noisenet_mobile/core/logging/app_logger.dart';
import 'package:noisenet_mobile/services/sound_analysis/on_device_sound_analysis_service.dart';
import 'package:noisenet_mobile/services/sound_analysis/sound_analysis_models.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppLogger.initialize);

  testWidgets('live PCM reaches YAMNet without creating an audio file',
      (tester) async {
    expect(await Permission.microphone.status, PermissionStatus.granted);

    final streamer = AudioStreamer()..sampleRate = 48000;
    final pcmFrames = StreamController<PcmAudioFrame>();
    final analysis = OnDeviceSoundAnalysisService();
    StreamSubscription<List<double>>? microphoneSubscription;
    addTearDown(() async {
      await microphoneSubscription?.cancel();
      await analysis.dispose();
      await pcmFrames.close();
    });

    expect(await analysis.start(pcmFrames.stream), isTrue);
    var actualSampleRate = 48000;
    microphoneSubscription = streamer.audioStream.listen((samples) {
      pcmFrames.add(PcmAudioFrame(
        samples: List<double>.unmodifiable(samples),
        sampleRate: actualSampleRate,
        capturedAt: DateTime.now(),
      ));
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    actualSampleRate = await streamer.actualSampleRate;

    final result = await analysis.results.first.timeout(
      const Duration(seconds: 15),
    );

    expect(result.topYamnetScores, hasLength(5));
    expect(result.confidence.isFinite, isTrue);
    expect(analysis.getDiagnostics()['inference_count'], greaterThan(0));
    expect(
        analysis.getDiagnostics()['audio_retention'], 'ephemeral_window_only');
    expect(analysis.getDiagnostics()['max_pcm_retention_ms'], 2895);
  });
}
