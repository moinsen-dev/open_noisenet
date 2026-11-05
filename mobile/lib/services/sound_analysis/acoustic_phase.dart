import 'dart:math' as math;

/// Pure interval logic shared by the app, exports and the offline benchmark.
/// Times are UTC epoch milliseconds. Scores are not calibrated probabilities.
class AcousticInterval {
  const AcousticInterval(this.start, this.end);
  final int start, end;
  int get duration => end - start;
  Map<String, Object?> toJson() => {'start_ms': start, 'end_ms': end};
}

class AcousticEvidence extends AcousticInterval {
  const AcousticEvidence(super.start, super.end, this.category);
  final String category;
}

String acousticFamily(String category) => switch (category) {
      'loud_conversation' || 'shouting_or_dispute' => 'speech',
      'party_or_music_with_people' || 'television_or_music' => 'music',
      'drilling' || 'hammering' || 'sawing' || 'construction_other' => 'tools',
      'road_traffic' => 'traffic',
      'household_appliance' => 'appliance',
      'animals' => 'animals',
      'furniture_movement' ||
      'footsteps_or_impact_noise' ||
      'door_or_impact' =>
        'impact',
      _ => 'unknown',
    };

String acousticFamilyLabel(String family) => switch (family) {
      'speech' => 'Sprachaktivität',
      'music' => 'Musik / Medien',
      'tools' => 'Werkzeuggeräusche',
      'traffic' => 'Straßenverkehr',
      'appliance' => 'Haushaltsgeräte',
      'animals' => 'Tiergeräusche',
      'impact' => 'Schritte / Stoßgeräusche',
      _ => 'Ungeklärt',
    };

/// Initial, versioned screening parameters, not a validated nuisance policy.
class AcousticPhasePolicy {
  const AcousticPhasePolicy({
    this.speechPauseMs = 90000,
    this.recentWindowMs = 300000,
    this.minimumRecentActivity = .2,
  });
  static const version = 'source_phases_v1';
  final int speechPauseMs, recentWindowMs;
  final double minimumRecentActivity;
  int pauseFor(String family) => switch (family) {
        'speech' => speechPauseMs,
        'music' || 'appliance' => 90000,
        'tools' => 120000,
        'traffic' => 45000,
        'animals' => 15000,
        _ => 3000,
      };
}

class AcousticPhase extends AcousticInterval {
  AcousticPhase(this.family, this.activity, this.endReason)
      : super(activity.first.start, activity.last.end);
  final String family, endReason;
  final List<AcousticInterval> activity;
  int get activeMs => activity.fold(0, (sum, part) => sum + part.duration);
  int get pauseMs => duration - activeMs;
  @override
  Map<String, Object?> toJson() => {
        'family': family,
        'start_ms': start,
        'end_ms': end,
        'active_ms': activeMs,
        'pause_ms': pauseMs,
        'activity': activity.map((p) => p.toJson()).toList(),
        'end_reason': endReason,
        'algorithm': AcousticPhasePolicy.version,
        'semantics': 'source_activity_not_verified_cause',
      };
}

List<AcousticInterval> unionAcousticIntervals(
    Iterable<AcousticInterval> input) {
  final sorted = input.where((p) => p.end > p.start).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  final result = <AcousticInterval>[];
  for (final part in sorted) {
    if (result.isNotEmpty && part.start <= result.last.end) {
      final last = result.removeLast();
      result.add(AcousticInterval(last.start, math.max(last.end, part.end)));
    } else {
      result.add(AcousticInterval(part.start, part.end));
    }
  }
  return result;
}

/// Only joins through explicitly observed inference coverage. Minute rows or
/// absence of source hints cannot establish that coverage. Overlapping sources
/// remain independent. Activity is unioned, so overlap is never double-counted.
List<AcousticPhase> buildAcousticPhases({
  required Iterable<AcousticEvidence> evidence,
  required Iterable<AcousticInterval> coverage,
  AcousticPhasePolicy policy = const AcousticPhasePolicy(),
}) {
  if (policy.speechPauseMs < 0 ||
      policy.recentWindowMs <= 0 ||
      !policy.minimumRecentActivity.isFinite ||
      policy.minimumRecentActivity < 0 ||
      policy.minimumRecentActivity > 1) {
    throw ArgumentError('Invalid acoustic phase policy');
  }
  final observed = unionAcousticIntervals(coverage);
  final byFamily = <String, List<AcousticInterval>>{};
  for (final hint in evidence) {
    final family = acousticFamily(hint.category);
    if (family == 'unknown' || hint.end <= hint.start) continue;
    // Clip hints at genuine inference gaps, including stale legacy segments.
    for (final window in observed) {
      final a = math.max(hint.start, window.start);
      final b = math.min(hint.end, window.end);
      if (b > a)
        byFamily.putIfAbsent(family, () => []).add(AcousticInterval(a, b));
    }
  }
  final phases = <AcousticPhase>[];
  for (final entry in byFamily.entries) {
    var current = <AcousticInterval>[];
    void finish(String reason) {
      if (current.isNotEmpty) {
        phases
            .add(AcousticPhase(entry.key, List.unmodifiable(current), reason));
      }
      current = [];
    }

    for (final next in unionAcousticIntervals(entry.value)) {
      if (current.isNotEmpty) {
        final previous = current.last;
        final gap = next.start - previous.end;
        final hasCoverage =
            observed.any((w) => w.start <= previous.end && w.end >= next.start);
        if (!hasCoverage) {
          finish('inference_gap');
        } else if (gap > policy.pauseFor(entry.key)) {
          finish('pause_limit');
        } else if (gap > 0) {
          // Check evidence BEFORE resumption: a long next segment must not
          // retroactively make an arbitrarily sparse chain continuous.
          final from =
              math.max(current.first.start, next.start - policy.recentWindowMs);
          final active = current.fold<int>(
              0,
              (sum, part) =>
                  sum +
                  math.max(
                      0,
                      math.min(part.end, next.start) -
                          math.max(part.start, from)));
          final span = next.start - from;
          if (span > 0 && active / span < policy.minimumRecentActivity) {
            finish('sparse_activity');
          }
        }
      }
      current.add(next);
    }
    if (current.isNotEmpty) {
      final last = current.last.end;
      final observedEnd =
          observed.where((w) => w.start < last && w.end >= last).first.end;
      finish(observedEnd - last > policy.pauseFor(entry.key)
          ? 'pause_limit'
          : 'end_of_observations');
    }
  }
  return phases..sort((a, b) => b.duration.compareTo(a.duration));
}
