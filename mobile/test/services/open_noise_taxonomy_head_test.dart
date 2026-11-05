import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/sound_analysis/open_noise_taxonomy_head.dart';
import 'package:noisenet_mobile/services/sound_analysis/sound_analysis_models.dart';

void main() {
  const labels = <String>[
    'Speech',
    'Conversation',
    'Music',
    'Dance music',
    'Drill',
    'Traffic noise, roadway noise',
    'Bark',
    'Silence',
  ];

  test('requires both music and people evidence for a party scene', () {
    final result = OpenNoiseTaxonomyHead().classify(
      yamnetScores: const [0.8, 0.5, 0.9, 0.6, 0, 0, 0, 0],
      labels: labels,
    );

    expect(result.category, OpenNoiseCategory.partyOrMusicWithPeople);
    expect(result.confidence, greaterThan(0.5));
  });

  test('maps source-specific AudioSet evidence into the controlled taxonomy',
      () {
    final result = OpenNoiseTaxonomyHead().classify(
      yamnetScores: const [0, 0, 0, 0, 0.95, 0.1, 0, 0],
      labels: labels,
    );

    expect(result.category, OpenNoiseCategory.drilling);
    expect(result.scores.keys, isNot(contains('Drill')));
  });

  test('keeps weak evidence in the explicit unknown bucket', () {
    final result = OpenNoiseTaxonomyHead().classify(
      yamnetScores: List<double>.filled(labels.length, 0.01),
      labels: labels,
    );

    expect(result.category, OpenNoiseCategory.unknownSoundSource);
  });

  test('does not promote a weak animal candidate into an animal detection', () {
    final result = OpenNoiseTaxonomyHead().classify(
      // Pooling applies a 0.65 primary-label weight, producing the exact
      // 0.1201171875 category confidence observed on the Huawei.
      yamnetScores: const [0.18479567307692308],
      labels: const ['Animal'],
    );

    expect(result.scores[OpenNoiseCategory.animals], 0.1201171875);
    expect(result.category, OpenNoiseCategory.unknownSoundSource);
  });

  test('retains strong bark evidence as an animal detection', () {
    final result = OpenNoiseTaxonomyHead().classify(
      yamnetScores: const [0.9],
      labels: const ['Bark'],
    );

    expect(result.category, OpenNoiseCategory.animals);
    expect(
      result.confidence,
      greaterThanOrEqualTo(
        OpenNoiseClassificationPolicy.animalMinimumConfidence,
      ),
    );
  });
}
