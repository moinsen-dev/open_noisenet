import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/core/logging/app_logger.dart';
import 'package:noisenet_mobile/services/sound_analysis/on_device_sound_analysis_service.dart';
import 'package:noisenet_mobile/services/sound_analysis/sound_analysis_models.dart';
import 'package:noisenet_mobile/services/sound_analysis/yamnet_inference_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppLogger.initialize);

  test('classifies a PCM window and exposes only structured history', () async {
    final engine = _FakeYamnetInferenceEngine();
    final service = OnDeviceSoundAnalysisService(engine: engine);
    final pcm = StreamController<PcmAudioFrame>();
    addTearDown(() async {
      await service.dispose();
      await pcm.close();
    });

    expect(await service.start(pcm.stream), isTrue);
    final resultFuture = service.results.first.timeout(
      const Duration(seconds: 2),
    );
    final now = DateTime.utc(2026, 8, 18, 20);
    pcm.add(PcmAudioFrame(
      samples: List<double>.filled(15600, 0.1),
      sampleRate: 16000,
      capturedAt: now,
    ));

    final result = await resultFuture;
    expect(result.category, OpenNoiseCategory.drilling);
    expect(service.getDiagnostics()['structured_history_frames'], 1);
    expect(
        service.getDiagnostics()['audio_retention'], 'ephemeral_window_only');
  });

  test('publishes a stable source interval from consecutive model frames',
      () async {
    final engine = _FakeYamnetInferenceEngine();
    final service = OnDeviceSoundAnalysisService(engine: engine);
    final pcm = StreamController<PcmAudioFrame>();
    addTearDown(() async {
      await service.dispose();
      await pcm.close();
    });

    expect(await service.start(pcm.stream), isTrue);
    final activityFuture = service.sourceActivity
        .firstWhere((snapshot) => snapshot.activeSegment != null)
        .timeout(const Duration(seconds: 2));
    final now = DateTime.utc(2026, 8, 18, 20);
    pcm.add(PcmAudioFrame(
      samples: List<double>.filled(23280, 0.1),
      sampleRate: 16000,
      capturedAt: now,
    ));

    final activity = await activityFuture;
    expect(activity.activeSegment!.category, OpenNoiseCategory.drilling);
    expect(activity.activeSegment!.evidenceFrameCount, 2);
    expect(
      service.getDiagnostics()['source_timing_resolution_ms'],
      480,
    );
    expect(
      service.getDiagnostics()['source_boundary_uncertainty_ms'],
      975,
    );
  });
}

class _FakeYamnetInferenceEngine implements YamnetInferenceEngine {
  bool _ready = false;

  @override
  bool get isReady => _ready;

  @override
  String get modelVersion => 'fake_yamnet';

  @override
  Future<void> initialize() async => _ready = true;

  @override
  Future<List<double>> run(List<double> waveform) async {
    expect(waveform, hasLength(15600));
    final scores = List<double>.filled(521, 0);
    scores[419] = 0.95; // Drill in the official YAMNet label list.
    return scores;
  }

  @override
  Future<void> close() async => _ready = false;
}
