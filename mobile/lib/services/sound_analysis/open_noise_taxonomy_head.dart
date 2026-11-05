import 'dart:math';

import 'sound_analysis_models.dart';

class TaxonomyClassification {
  final String category;
  final double confidence;
  final Map<String, double> scores;
  final List<RawSoundScore> topYamnetScores;

  const TaxonomyClassification({
    required this.category,
    required this.confidence,
    required this.scores,
    required this.topYamnetScores,
  });
}

/// Versioned first OpenNoiseNet head on top of YAMNet scores.
///
/// This is deliberately a transparent deterministic taxonomy adapter. It is
/// the production-safe bridge until a learned head has been trained and
/// evaluated on labelled through-wall and cross-device recordings.
class OpenNoiseTaxonomyHead {
  static const version = OpenNoiseClassificationPolicy.taxonomyVersion;

  TaxonomyClassification classify({
    required List<double> yamnetScores,
    required List<String> labels,
  }) {
    if (yamnetScores.length != labels.length) {
      throw ArgumentError(
        'YAMNet score/label mismatch: ${yamnetScores.length} vs ${labels.length}',
      );
    }

    final byLabel = <String, double>{
      for (var i = 0; i < labels.length; i++) labels[i]: yamnetScores[i],
    };

    final people = _pool(byLabel, const {
      'Speech',
      'Conversation',
      'Chatter',
      'Crowd',
      'Hubbub, speech noise, speech babble',
    });
    final music = _pool(byLabel, const {
      'Music',
      'Song',
      'Background music',
      'Dance music',
      'Electronic dance music',
      'House music',
      'Techno',
      'Bass drum',
    });

    final scores = <String, double>{
      OpenNoiseCategory.loudConversation: people,
      OpenNoiseCategory.shoutingOrDispute: _pool(byLabel, const {
        'Shout',
        'Bellow',
        'Yell',
        'Children shouting',
        'Screaming',
      }),
      OpenNoiseCategory.partyOrMusicWithPeople: _coOccurrence(music, people),
      OpenNoiseCategory.televisionOrMusic: max(
        _pool(byLabel, const {'Television', 'Radio'}),
        music * (1 - (0.45 * people)),
      ),
      OpenNoiseCategory.drilling:
          _pool(byLabel, const {'Drill', "Dental drill, dentist's drill"}),
      OpenNoiseCategory.hammering:
          _pool(byLabel, const {'Hammer', 'Jackhammer'}),
      OpenNoiseCategory.sawing: _pool(byLabel, const {'Sawing', 'Chainsaw'}),
      OpenNoiseCategory.constructionOther: _pool(byLabel, const {
        'Tools',
        'Power tool',
        'Sanding',
        'Filing (rasp)',
        'Engine',
      }),
      OpenNoiseCategory.furnitureMovement: _pool(byLabel, const {
        'Scrape',
        'Roll',
        'Creak',
        'Thump, thud',
        'Thunk',
      }),
      OpenNoiseCategory.footstepsOrImpactNoise: _pool(byLabel, const {
        'Walk, footsteps',
        'Run',
        'Shuffle',
        'Patter',
        'Thump, thud',
      }),
      OpenNoiseCategory.doorOrImpact: _pool(byLabel, const {
        'Door',
        'Slam',
        'Knock',
        'Bang',
        'Smash, crash',
      }),
      OpenNoiseCategory.householdAppliance: _pool(byLabel, const {
        'Vacuum cleaner',
        'Blender',
        'Microwave oven',
        'Hair dryer',
        'Mechanical fan',
        'Air conditioning',
        'Sewing machine',
        'Electric shaver, electric razor',
      }),
      OpenNoiseCategory.roadTraffic: _pool(byLabel, const {
        'Traffic noise, roadway noise',
        'Motor vehicle (road)',
        'Car',
        'Car passing by',
        'Truck',
        'Bus',
        'Motorcycle',
        'Vehicle horn, car horn, honking',
      }),
      OpenNoiseCategory.animals: _pool(byLabel, const {
        'Animal',
        'Domestic animals, pets',
        'Dog',
        'Bark',
        'Cat',
        'Meow',
        'Bird',
        'Bird vocalization, bird call, bird song',
      }),
    };

    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = ranked.first;
    final category = OpenNoiseClassificationPolicy.accepts(
      best.key,
      best.value,
    )
        ? best.key
        : OpenNoiseCategory.unknownSoundSource;
    final confidence = category == OpenNoiseCategory.unknownSoundSource
        ? (0.5 - best.value).clamp(0.15, 0.5).toDouble()
        : best.value.clamp(0.0, 1.0).toDouble();

    final rawScores = <RawSoundScore>[
      for (var i = 0; i < labels.length; i++)
        RawSoundScore(label: labels[i], score: yamnetScores[i]),
    ]..sort((a, b) => b.score.compareTo(a.score));

    return TaxonomyClassification(
      category: category,
      confidence: confidence,
      scores: Map.unmodifiable(scores),
      topYamnetScores: List.unmodifiable(rawScores.take(5)),
    );
  }

  double _pool(Map<String, double> byLabel, Set<String> names) {
    final found = names
        .map((name) => byLabel[name] ?? 0.0)
        .where((score) => score > 0)
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (found.isEmpty) return 0;

    const weights = <double>[0.65, 0.25, 0.10];
    var score = 0.0;
    for (var i = 0; i < min(found.length, weights.length); i++) {
      score += found[i] * weights[i];
    }
    return score.clamp(0.0, 1.0).toDouble();
  }

  double _coOccurrence(double first, double second) {
    if (first <= 0 || second <= 0) return 0;
    return (sqrt(first * second) * 1.05).clamp(0.0, 1.0).toDouble();
  }
}
