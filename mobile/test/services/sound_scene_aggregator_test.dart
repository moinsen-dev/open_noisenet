import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/sound_analysis/sound_analysis_models.dart';
import 'package:noisenet_mobile/services/sound_analysis/sound_scene_aggregator.dart';

void main() {
  test('aggregates overlapping frames without retaining waveform data', () {
    final start = DateTime.utc(2026, 8, 18, 20);
    final frames = List.generate(4, (index) {
      final frameStart = start.add(Duration(milliseconds: 480 * index));
      return SoundClassificationFrame(
        windowStart: frameStart,
        windowEnd: frameStart.add(const Duration(milliseconds: 975)),
        category: OpenNoiseCategory.roadTraffic,
        confidence: 0.7,
        categoryScores: const {
          OpenNoiseCategory.roadTraffic: 0.7,
          OpenNoiseCategory.animals: 0.05,
        },
        topYamnetScores: const [
          RawSoundScore(label: 'Traffic noise, roadway noise', score: 0.8),
        ],
        inferenceMs: 12,
      );
    });

    final summary = const SoundSceneAggregator().summarize(
      frames: frames,
      start: start,
      end: start.add(const Duration(seconds: 3)),
    );

    expect(summary, isNotNull);
    expect(summary!.category, OpenNoiseCategory.roadTraffic);
    expect(summary.frameCount, 4);
    expect(summary.toMetadata()['audio_retention'], 'ephemeral_window_only');
    expect(summary.toMetadata()['speech_recognition'], isFalse);
    expect(
      summary.toMetadata()['model'],
      'yamnet_float32_mediapipe_latest',
    );
  });

  test('repeated weak animal candidates do not become a confident event', () {
    final start = DateTime.utc(2026, 8, 19, 9);
    final frames = List.generate(4, (index) {
      final frameStart = start.add(Duration(milliseconds: 480 * index));
      return SoundClassificationFrame(
        windowStart: frameStart,
        windowEnd: frameStart.add(const Duration(milliseconds: 975)),
        category: OpenNoiseCategory.animals,
        confidence: 0.1201171875,
        categoryScores: const {
          OpenNoiseCategory.animals: 0.1201171875,
        },
        topYamnetScores: const [
          RawSoundScore(label: 'Animal', score: 0.18479567307692308),
        ],
        inferenceMs: 12,
      );
    });

    final summary = const SoundSceneAggregator().summarize(
      frames: frames,
      start: start,
      end: start.add(const Duration(seconds: 3)),
    );

    expect(summary, isNotNull);
    expect(summary!.category, OpenNoiseCategory.unknownSoundSource);
    expect(summary.isConfident, isFalse);
  });
}
