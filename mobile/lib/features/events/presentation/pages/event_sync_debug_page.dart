import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../features/noise_monitoring/data/models/noise_event_model.dart';
import '../../../../features/noise_monitoring/data/repositories/event_repository.dart';
import '../../../../services/audio_capture_service.dart';
import '../../../../services/backend_sync_service.dart';
import '../../../../services/event_detection_service.dart';
import '../../../../services/ios_background_service.dart';
import '../../../../services/recording_service.dart';
import '../../../../widgets/shared_app_bar.dart';

class EventSyncDebugPage extends StatefulWidget {
  const EventSyncDebugPage({super.key});

  @override
  State<EventSyncDebugPage> createState() => _EventSyncDebugPageState();
}

class _EventSyncDebugPageState extends State<EventSyncDebugPage> {
  final BackendSyncService _backendSync = GetIt.instance<BackendSyncService>();
  final AudioCaptureService _audioCapture =
      GetIt.instance<AudioCaptureService>();
  final EventDetectionService _eventDetection = EventDetectionService();
  final RecordingService _recordingService = RecordingService();
  final IOSBackgroundService _iosBackgroundService = IOSBackgroundService();

  late Future<_EventSyncSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  Future<_EventSyncSnapshot> _loadSnapshot() async {
    final repository = await EventRepository.getInstance();
    final backendStatus = await _backendSync.getBackendStatus();
    final recentEvents = await repository.getRecentEvents(limit: 15);
    final recordingStatus = await _recordingService.getStorageInfo();

    return _EventSyncSnapshot(
      backendStatus: backendStatus,
      recentEvents: recentEvents,
      audioDiagnostics: _audioCapture.getDiagnostics(),
      eventDetectionStatus: _eventDetection.getStatus(),
      recordingStatus: recordingStatus,
      iosBackgroundStatus:
          Platform.isIOS ? _iosBackgroundService.getServiceStatistics() : null,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
    await _snapshotFuture;
  }

  Future<void> _syncQueuedNow() async {
    final submitted = await _backendSync.syncQueuedEvents();
    if (!mounted) {
      return;
    }

    await _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Submitted $submitted queued events'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SharedAppBar(
        pageTitle: 'Event Sync',
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_EventSyncSnapshot>(
          future: _snapshotFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!;
            final backendStatus = data.backendStatus;
            final proContext =
                backendStatus['pro_context'] as Map<String, dynamic>?;
            final policyCounts =
                proContext?['policy_counts'] as Map<String, dynamic>?;
            final recentEvents = data.recentEvents;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Backend',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        _KeyValueRow(
                          label: 'Mode',
                          value:
                              '${backendStatus['mode']} / ${backendStatus['submission_mode']}',
                        ),
                        _KeyValueRow(
                          label: 'Backend URL',
                          value: '${backendStatus['backend_url'] ?? 'unknown'}',
                        ),
                        _KeyValueRow(
                          label: 'Device ID',
                          value: '${backendStatus['device_id'] ?? 'not set'}',
                        ),
                        _KeyValueRow(
                          label: 'Assigned Site',
                          value:
                              '${backendStatus['assigned_site_id'] ?? 'unassigned'}',
                        ),
                        _KeyValueRow(
                          label: 'Assigned Zone',
                          value:
                              '${backendStatus['assigned_zone_id'] ?? 'none'}',
                        ),
                        _KeyValueRow(
                          label: 'Calibration Profile',
                          value:
                              '${backendStatus['assigned_calibration_profile_id'] ?? 'none'}',
                        ),
                        _KeyValueRow(
                          label: 'Authenticated',
                          value: '${backendStatus['authenticated'] ?? false}',
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _syncQueuedNow,
                            icon: const Icon(Icons.sync),
                            label: const Text('Sync Queued Events Now'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pro Context',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        _KeyValueRow(
                          label: 'Access State',
                          value:
                              '${backendStatus['pro_context_access_state'] ?? 'unavailable'}',
                        ),
                        _KeyValueRow(
                          label: 'Organization',
                          value:
                              '${backendStatus['assigned_organization_name'] ?? backendStatus['assigned_organization_id'] ?? 'unassigned'}',
                        ),
                        _KeyValueRow(
                          label: 'Site',
                          value:
                              '${backendStatus['assigned_site_name'] ?? backendStatus['assigned_site_id'] ?? 'unassigned'}',
                        ),
                        _KeyValueRow(
                          label: 'Zone',
                          value:
                              '${backendStatus['assigned_zone_name'] ?? backendStatus['assigned_zone_id'] ?? 'none'}',
                        ),
                        _KeyValueRow(
                          label: 'Calibration',
                          value:
                              '${backendStatus['assigned_calibration_profile_name'] ?? backendStatus['assigned_calibration_profile_id'] ?? 'none'}',
                        ),
                        _KeyValueRow(
                          label: 'Effective Policy',
                          value:
                              '${backendStatus['effective_policy_name'] ?? 'none'}',
                        ),
                        _KeyValueRow(
                          label: 'Policy Scope',
                          value:
                              '${backendStatus['effective_policy_scope'] ?? 'n/a'} / ${backendStatus['effective_evidence_mode'] ?? 'n/a'}',
                        ),
                        _KeyValueRow(
                          label: 'Policy Counts',
                          value:
                              'org ${policyCounts?['organization'] ?? 0} / site ${policyCounts?['site'] ?? 0} / zone ${policyCounts?['zone'] ?? 0}',
                        ),
                        _KeyValueRow(
                          label: 'Context Refreshed',
                          value:
                              '${backendStatus['pro_context_refreshed_at'] ?? 'never'}',
                        ),
                        _KeyValueRow(
                          label: 'Context Error',
                          value:
                              '${backendStatus['pro_context_error'] ?? 'none'}',
                        ),
                        if (proContext != null &&
                            (proContext['source_note'] != null ||
                                proContext['policies'] != null)) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Resolved Snapshot',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          _KeyValueRow(
                            label: 'Source',
                            value: '${proContext['source_note'] ?? 'unknown'}',
                          ),
                          _KeyValueRow(
                            label: 'Effective Retention',
                            value:
                                '${backendStatus['effective_policy_retention_days'] ?? 'n/a'} days',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Lifecycle Counts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _CountChip(
                      label: 'Local',
                      value: (backendStatus['local_events'] as int?) ?? 0,
                    ),
                    _CountChip(
                      label: 'Queued',
                      value: (backendStatus['queued_events'] as int?) ?? 0,
                    ),
                    _CountChip(
                      label: 'Uploaded',
                      value: (backendStatus['uploaded_events'] as int?) ?? 0,
                    ),
                    _CountChip(
                      label: 'Acknowledged',
                      value:
                          (backendStatus['acknowledged_events'] as int?) ?? 0,
                    ),
                    _CountChip(
                      label: 'Failed',
                      value: (backendStatus['failed_events'] as int?) ?? 0,
                    ),
                    _CountChip(
                      label: 'Device Classified',
                      value:
                          (backendStatus['device_classified_events'] as int?) ??
                              0,
                    ),
                    _CountChip(
                      label: 'Server Classified',
                      value:
                          (backendStatus['server_classified_events'] as int?) ??
                              0,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _KeyValueRow(
                          label: 'Last ACK',
                          value:
                              '${backendStatus['last_acknowledged_at'] ?? 'none'}',
                        ),
                        _KeyValueRow(
                          label: 'Last Heartbeat',
                          value:
                              '${backendStatus['last_heartbeat_at'] ?? 'none'}',
                        ),
                        _KeyValueRow(
                          label: 'Heartbeat Error',
                          value:
                              '${backendStatus['last_heartbeat_error'] ?? 'none'}',
                        ),
                        _KeyValueRow(
                          label: 'Last Analysis',
                          value:
                              '${backendStatus['last_analysis_update_at'] ?? 'none'}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sensor Runtime',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        _KeyValueRow(
                          label: 'Capturing',
                          value:
                              '${data.audioDiagnostics['isCapturing'] ?? false}',
                        ),
                        _KeyValueRow(
                          label: 'Sensor Mode',
                          value:
                              '${backendStatus['sensor_mode_active'] ?? false}',
                        ),
                        _KeyValueRow(
                          label: 'Samples',
                          value:
                              '${data.audioDiagnostics['capturedSampleCount'] ?? 0}',
                        ),
                        _KeyValueRow(
                          label: 'Last Sample',
                          value:
                              '${data.audioDiagnostics['lastSampleAt'] ?? 'none'}',
                        ),
                        _KeyValueRow(
                          label: 'Stall Age',
                          value:
                              '${data.audioDiagnostics['timeSinceLastSampleMs'] ?? 'n/a'} ms',
                        ),
                        _KeyValueRow(
                          label: 'Restarts',
                          value:
                              '${data.audioDiagnostics['restartCount'] ?? 0}',
                        ),
                        _KeyValueRow(
                          label: 'Last Restart',
                          value:
                              '${data.audioDiagnostics['lastRestartAt'] ?? 'none'}',
                        ),
                        _KeyValueRow(
                          label: 'Detector',
                          value:
                              '${data.eventDetectionStatus['isMonitoring'] ?? false} / samples ${data.eventDetectionStatus['sampleCount'] ?? 0}',
                        ),
                        _KeyValueRow(
                          label: 'Recorder',
                          value:
                              '${data.recordingStatus['active_buffers'] ?? 0} buffers / ${data.recordingStatus['settings']?['enabled'] ?? false}',
                        ),
                        if (data.iosBackgroundStatus != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'iOS Background',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          _KeyValueRow(
                            label: 'Session Active',
                            value:
                                '${data.iosBackgroundStatus!['isActive'] ?? false}',
                          ),
                          _KeyValueRow(
                            label: 'Task Renewals',
                            value:
                                '${data.iosBackgroundStatus!['backgroundTaskRenewalCount'] ?? 0}',
                          ),
                          _KeyValueRow(
                            label: 'Last Renewal',
                            value:
                                '${data.iosBackgroundStatus!['lastBackgroundTaskRenewedAt'] ?? 'none'}',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Recent Local Events',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (recentEvents.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No local reportable events stored yet.'),
                    ),
                  )
                else
                  ...recentEvents.map((event) => Card(
                        child: ListTile(
                          title: Text(
                            '${event.leqDb.toStringAsFixed(1)} dB · ${event.lifecycleState}',
                          ),
                          subtitle: Text(
                            '${_shortId(event.eventUuid ?? event.id ?? 'no-id')}'
                            '\nstart: ${event.timestampStart.toIso8601String()}'
                            '\nanalysis: ${event.analysisState} / ${event.classificationLabel ?? 'unclassified'}'
                            '\nserver: ${event.serverEventId ?? 'pending'}'
                            '\nreportability: ${event.reportabilityScore?.toStringAsFixed(2) ?? 'n/a'}',
                          ),
                          isThreeLine: true,
                          trailing: Icon(
                            event.serverAcknowledgedAt != null
                                ? Icons.cloud_done
                                : event.lifecycleState ==
                                        EventLifecycleState.queuedForUpload
                                    ? Icons.cloud_queue
                                    : Icons.phone_iphone,
                          ),
                        ),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }

  String _shortId(String value) {
    if (value.length <= 12) {
      return value;
    }
    return '${value.substring(0, 8)}…${value.substring(value.length - 4)}';
  }
}

class _EventSyncSnapshot {
  final Map<String, dynamic> backendStatus;
  final List<NoiseEventModel> recentEvents;
  final Map<String, dynamic> audioDiagnostics;
  final Map<String, dynamic> eventDetectionStatus;
  final Map<String, dynamic> recordingStatus;
  final Map<String, dynamic>? iosBackgroundStatus;

  const _EventSyncSnapshot({
    required this.backendStatus,
    required this.recentEvents,
    required this.audioDiagnostics,
    required this.eventDetectionStatus,
    required this.recordingStatus,
    required this.iosBackgroundStatus,
  });
}

class _CountChip extends StatelessWidget {
  final String label;
  final int value;

  const _CountChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValueRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
