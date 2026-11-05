import 'package:flutter/material.dart';

import '../../../../services/audio_capture_service.dart';
import '../../../noise_diary/data/diary_repository.dart';
import '../../../noise_diary/presentation/noise_diary_page.dart';
import '../../../../services/sound_analysis/on_device_sound_analysis_service.dart';
import '../../../../services/sound_analysis/sound_analysis_models.dart';

class LiveSoundAnalysisCard extends StatelessWidget {
  final OnDeviceSoundAnalysisService analysisService;
  final AudioCaptureService audioCaptureService;

  const LiveSoundAnalysisCard({
    super.key,
    required this.analysisService,
    required this.audioCaptureService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SoundSourceActivitySnapshot>(
      stream: analysisService.sourceActivity,
      initialData: analysisService.latestSourceActivity,
      builder: (context, snapshot) {
        final activity = snapshot.data;
        final active = activity?.activeSegment;
        final lastCompleted = activity?.lastCompletedSegment;
        final latestFrame = analysisService.latestFrame;
        final latestCategory = activity?.latestCategory;
        final isUnknown = latestCategory == null ||
            latestCategory == OpenNoiseCategory.unknownSoundSource;
        final shownCategory = active?.category ?? latestCategory;
        final shownConfidence =
            active?.confidence ?? activity?.latestConfidence;
        final evidence = active?.strongestYamnetScores ??
            latestFrame?.topYamnetScores ??
            const <RawSoundScore>[];
        final calibrationOffset = audioCaptureService.calibrationOffset;
        final isCalibrated = calibrationOffset.abs() > 0.0001;

        return Card(
          key: const ValueKey('live_sound_analysis_card'),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.hearing,
                      size: 20,
                      color: active != null ? Colors.green : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'On-device source analysis',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    _StatusPill(
                      text: _statusText(
                        modelReady: analysisService.isReady,
                        active: active != null,
                        isUnknown: isUnknown,
                      ),
                      color: active != null ? Colors.green : Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _sourceLabel(shownCategory),
                  key: const ValueKey('live_source_category'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                if (shownConfidence != null && !isUnknown)
                  Text(
                    'Model confidence ${(shownConfidence * 100).round()}%',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  Text(
                    analysisService.isReady
                        ? 'Waiting for a stable source hypothesis'
                        : 'The local model is starting; numeric monitoring continues',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                if (active != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 20, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Source active for ${_formatDuration(active.duration)}',
                          key: const ValueKey('live_source_duration'),
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('add_active_sound_to_diary'),
                    onPressed: () {
                      final hint = DiarySoundHint(
                          category: active.category,
                          start: active.start,
                          end: active.end);
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => NoiseDiaryPage(initialSoundHint: hint),
                      ));
                    },
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Vorschlag im Tagebuch ergänzen'),
                  ),
                ] else if (lastCompleted != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Last interval: ${_sourceLabel(lastCompleted.category)} · '
                    '${_formatDuration(lastCompleted.duration)} · '
                    '${(lastCompleted.confidence * 100).round()}%',
                    key: const ValueKey('last_source_interval'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('add_last_sound_to_diary'),
                    onPressed: () {
                      final hint = DiarySoundHint(
                          category: lastCompleted.category,
                          start: lastCompleted.start,
                          end: lastCompleted.end);
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => NoiseDiaryPage(initialSoundHint: hint),
                      ));
                    },
                    icon: const Icon(Icons.note_add_outlined),
                    label: Text(
                        'Letzten Vorschlag übernehmen · ${TimeOfDay.fromDateTime(lastCompleted.start.toLocal()).format(context)}'),
                  ),
                ],
                if (evidence.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Strongest model evidence',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: evidence.take(3).map((score) {
                      return Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          '${score.label} ${(score.score * 100).round()}%',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 9),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.privacy_tip_outlined, size: 17),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'About 0.5 s timing resolution. No speech recognition; '
                        'model audio stays only in short-lived memory.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(
                      isCalibrated ? Icons.verified_outlined : Icons.science,
                      size: 17,
                      color: isCalibrated ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        isCalibrated
                            ? 'Level offset ${_signed(calibrationOffset)} dB; '
                                'reference method still determines measurement quality.'
                            : 'Sound level is an uncalibrated estimate.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusText({
    required bool modelReady,
    required bool active,
    required bool isUnknown,
  }) {
    if (!modelReady) return 'STARTING';
    if (active) return 'SOURCE ACTIVE';
    if (!isUnknown) return 'VERIFYING';
    return 'LISTENING';
  }

  String _sourceLabel(String? category) {
    switch (category) {
      case OpenNoiseCategory.loudConversation:
        return 'Loud conversation';
      case OpenNoiseCategory.shoutingOrDispute:
        return 'Shouting or dispute';
      case OpenNoiseCategory.partyOrMusicWithPeople:
        return 'Party or music with people';
      case OpenNoiseCategory.televisionOrMusic:
        return 'Television or music';
      case OpenNoiseCategory.drilling:
        return 'Drilling';
      case OpenNoiseCategory.hammering:
        return 'Hammering';
      case OpenNoiseCategory.sawing:
        return 'Sawing';
      case OpenNoiseCategory.constructionOther:
        return 'Other construction noise';
      case OpenNoiseCategory.furnitureMovement:
        return 'Furniture movement';
      case OpenNoiseCategory.footstepsOrImpactNoise:
        return 'Footsteps or impact noise';
      case OpenNoiseCategory.doorOrImpact:
        return 'Door or impact';
      case OpenNoiseCategory.householdAppliance:
        return 'Household appliance';
      case OpenNoiseCategory.roadTraffic:
        return 'Road traffic';
      case OpenNoiseCategory.animals:
        return 'Animals';
      default:
        return 'No stable source yet';
    }
  }

  String _formatDuration(Duration duration) {
    final milliseconds = duration.inMilliseconds;
    if (milliseconds < 60000) {
      return '${(milliseconds / 1000).toStringAsFixed(1)} s';
    }
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}m ${seconds}s';
  }

  String _signed(double value) =>
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
