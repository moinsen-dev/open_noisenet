import 'dart:collection';

/// A short, in-memory PCM frame. Samples are mono and normalized to [-1, 1].
///
/// Frames are never persisted by the sound-analysis pipeline. They only live
/// in its bounded inference backlog and are dropped when monitoring stops.
class PcmAudioFrame {
  final List<double> samples;
  final int sampleRate;
  final DateTime capturedAt;

  const PcmAudioFrame({
    required this.samples,
    required this.sampleRate,
    required this.capturedAt,
  });
}

class RawSoundScore {
  final String label;
  final double score;

  const RawSoundScore({required this.label, required this.score});

  Map<String, dynamic> toJson() => {
        'label': label,
        'score': score,
      };
}

/// One model result for a 0.975 second PCM window.
class SoundClassificationFrame {
  final DateTime windowStart;
  final DateTime windowEnd;
  final String category;
  final double confidence;
  final Map<String, double> categoryScores;
  final List<RawSoundScore> topYamnetScores;
  final int inferenceMs;

  const SoundClassificationFrame({
    required this.windowStart,
    required this.windowEnd,
    required this.category,
    required this.confidence,
    required this.categoryScores,
    required this.topYamnetScores,
    required this.inferenceMs,
  });
}

/// A source hypothesis with model-derived acoustic boundaries.
///
/// This interval is intentionally separate from a regulatory rolling-Leq
/// event. Its boundaries come from overlapping YAMNet frames and therefore
/// describe how long the source evidence was present, within the documented
/// model-window uncertainty.
class SoundSourceSegment {
  final DateTime start;
  final DateTime end;
  final String category;
  final double confidence;
  final int evidenceFrameCount;
  final List<RawSoundScore> strongestYamnetScores;
  final String timingBasis;

  const SoundSourceSegment({
    required this.start,
    required this.end,
    required this.category,
    required this.confidence,
    required this.evidenceFrameCount,
    required this.strongestYamnetScores,
    required this.timingBasis,
  });

  Duration get duration => end.difference(start);

  Map<String, dynamic> toJson() => {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'duration_ms': duration.inMilliseconds,
        'category': category,
        'confidence': confidence,
        'evidence_frame_count': evidenceFrameCount,
        'top_yamnet_scores':
            strongestYamnetScores.map((score) => score.toJson()).toList(),
        'timing_basis': timingBasis,
      };
}

/// Live structured state for the monitor UI. It contains no PCM samples.
class SoundSourceActivitySnapshot {
  final bool isFinal;
  final DateTime observedAt;
  final String latestCategory;
  final double latestConfidence;
  final SoundSourceSegment? activeSegment;
  final SoundSourceSegment? lastCompletedSegment;

  const SoundSourceActivitySnapshot({
    this.isFinal = false,
    required this.observedAt,
    required this.latestCategory,
    required this.latestConfidence,
    required this.activeSegment,
    required this.lastCompletedSegment,
  });
}

/// Event-level scene evidence aggregated from overlapping model frames.
class SoundSceneSummary {
  final DateTime start;
  final DateTime end;
  final String category;
  final double confidence;
  final int frameCount;
  final Map<String, double> categoryScores;
  final List<RawSoundScore> strongestYamnetScores;

  const SoundSceneSummary({
    required this.start,
    required this.end,
    required this.category,
    required this.confidence,
    required this.frameCount,
    required this.categoryScores,
    required this.strongestYamnetScores,
  });

  bool get isConfident =>
      OpenNoiseClassificationPolicy.accepts(category, confidence);

  Map<String, dynamic> toMetadata() => {
        'category': category,
        'confidence': confidence,
        'frame_count': frameCount,
        'category_scores': categoryScores,
        'top_yamnet_scores':
            strongestYamnetScores.map((score) => score.toJson()).toList(),
        'model': 'yamnet_float32_mediapipe_latest',
        'taxonomy_head': OpenNoiseClassificationPolicy.taxonomyVersion,
        'audio_retention': 'ephemeral_window_only',
        'speech_recognition': false,
      };
}

/// Stable OpenNoiseNet categories sent to the backend.
abstract final class OpenNoiseCategory {
  static const loudConversation = 'loud_conversation';
  static const shoutingOrDispute = 'shouting_or_dispute';
  static const partyOrMusicWithPeople = 'party_or_music_with_people';
  static const televisionOrMusic = 'television_or_music';
  static const drilling = 'drilling';
  static const hammering = 'hammering';
  static const sawing = 'sawing';
  static const constructionOther = 'construction_other';
  static const furnitureMovement = 'furniture_movement';
  static const footstepsOrImpactNoise = 'footsteps_or_impact_noise';
  static const doorOrImpact = 'door_or_impact';
  static const householdAppliance = 'household_appliance';
  static const roadTraffic = 'road_traffic';
  static const animals = 'animals';
  static const unknownSoundSource = 'unknown_sound_source';

  static const values = <String>{
    loudConversation,
    shoutingOrDispute,
    partyOrMusicWithPeople,
    televisionOrMusic,
    drilling,
    hammering,
    sawing,
    constructionOther,
    furnitureMovement,
    footstepsOrImpactNoise,
    doorOrImpact,
    householdAppliance,
    roadTraffic,
    animals,
    unknownSoundSource,
  };
}

/// Shared acceptance policy for taxonomy frames, stable source intervals and
/// event-level summaries.
///
/// Animal is deliberately more conservative because it pools several broad
/// AudioSet context labels in addition to specific barks and vocalizations.
/// The threshold remains a field-tuned screening boundary, not a calibrated
/// probability or a claim about the physical origin of the sound.
abstract final class OpenNoiseClassificationPolicy {
  static const taxonomyVersion = 'open_noise_taxonomy_v2';
  static const defaultMinimumConfidence = 0.18;
  static const animalMinimumConfidence = 0.24;

  static double minimumConfidenceFor(String category) =>
      category == OpenNoiseCategory.animals
          ? animalMinimumConfidence
          : defaultMinimumConfidence;

  static bool accepts(String category, double confidence) =>
      category != OpenNoiseCategory.unknownSoundSource &&
      confidence >= minimumConfidenceFor(category);
}

/// Bounded structured-result history. No waveform samples are stored here.
class SoundFrameHistory {
  final Duration retention;
  final Queue<SoundClassificationFrame> _frames =
      Queue<SoundClassificationFrame>();

  SoundFrameHistory({this.retention = const Duration(minutes: 30)});

  List<SoundClassificationFrame> get frames => List.unmodifiable(_frames);

  void add(SoundClassificationFrame frame) {
    _frames.addLast(frame);
    final cutoff = frame.windowEnd.subtract(retention);
    while (_frames.isNotEmpty && _frames.first.windowEnd.isBefore(cutoff)) {
      _frames.removeFirst();
    }
  }

  void clear() => _frames.clear();
}
