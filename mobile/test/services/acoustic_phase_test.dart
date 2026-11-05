import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/sound_analysis/acoustic_phase.dart';

void main() {
  AcousticEvidence e(int a, int b, [String category = 'loud_conversation']) =>
      AcousticEvidence(a * 1000, b * 1000, category);
  const coverage = [AcousticInterval(0, 3600000)];

  test('33 minute speech scene survives pauses and an overlapping door', () {
    final evidence = [
      for (var t = 0; t < 1980; t += 30) e(t, t + 20),
      e(900, 903, 'door_or_impact'),
      e(1970, 1980)
    ];
    final phases = buildAcousticPhases(evidence: evidence, coverage: coverage);
    final speech = phases.where((p) => p.family == 'speech').single;
    expect(speech.duration, 1980000);
    expect(speech.activeMs, 1330000);
    expect(speech.pauseMs, 650000);
    expect(phases.where((p) => p.family == 'impact'), hasLength(1));
  });

  test('long absence and real inference gap split even strong speech', () {
    final separated = buildAcousticPhases(
        evidence: [e(0, 300), e(480, 900)], coverage: coverage);
    expect(separated, hasLength(2));
    expect(separated.last.endReason, 'pause_limit');
    final outage = buildAcousticPhases(evidence: [
      e(0, 900)
    ], coverage: const [
      AcousticInterval(0, 400000),
      AcousticInterval(405000, 900000)
    ]);
    expect(outage, hasLength(2));
    expect(outage.last.endReason, 'inference_gap');
    expect(outage.fold<int>(0, (sum, p) => sum + p.activeMs), 895000);
  });

  test(
      'sparse bursts do not chain into an hour and trailing absence is excluded',
      () {
    final phases = buildAcousticPhases(
        evidence: [for (var t = 0; t < 3600; t += 60) e(t, t + 1)],
        coverage: coverage);
    expect(phases, hasLength(60));
    expect(phases.every((p) => p.duration == 1000), isTrue);
  });

  test('tool changes form one phase, concurrent speech stays independent', () {
    final phases = buildAcousticPhases(evidence: [
      e(0, 60, 'drilling'),
      e(70, 140, 'hammering'),
      e(150, 220, 'sawing'),
      e(90, 200)
    ], coverage: coverage);
    expect(phases, hasLength(2));
    expect(phases.first.family, 'tools');
    expect(phases.first.duration, 220000);
    expect(phases.first.activeMs, 200000);
  });

  test(
      'overlap is unioned, unknown is not relabelled, no invented old coverage',
      () {
    expect(buildAcousticPhases(evidence: [e(0, 30)], coverage: []), isEmpty);
    final phases = buildAcousticPhases(
        evidence: [e(0, 30), e(20, 40), e(0, 100, 'unknown_sound_source')],
        coverage: coverage);
    expect(phases.single.activeMs, 40000);
    expect(phases.single.pauseMs, 0);
  });

  test('future activity cannot retrospectively bridge sparse evidence', () {
    final phases = buildAcousticPhases(
        evidence: [e(0, 1), e(80, 500)], coverage: coverage);
    expect(phases, hasLength(2));
    expect(phases.last.endReason, 'sparse_activity');
  });

  test('order invariant and invalid policy rejected', () {
    final evidence = [e(0, 40), e(55, 80), e(100, 200)];
    expect(
        buildAcousticPhases(evidence: evidence.reversed, coverage: coverage)
            .single
            .toJson(),
        buildAcousticPhases(evidence: evidence, coverage: coverage)
            .single
            .toJson());
    expect(
        () => buildAcousticPhases(
            evidence: evidence,
            coverage: coverage,
            policy: const AcousticPhasePolicy(minimumRecentActivity: -1)),
        throwsArgumentError);
  });
}
