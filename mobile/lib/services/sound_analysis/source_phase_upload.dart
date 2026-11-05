import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../features/noise_diary/data/diary_repository.dart';
import 'acoustic_phase.dart';
import 'multi_source_tracker.dart';
import 'phase_upload_transport.dart';
import 'sound_analysis_models.dart';

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

Future<String> phasePayloadDigest(Map<String, dynamic> payload) async =>
    (await Sha256().hash(utf8.encode(jsonEncode(_canonical(payload)))))
        .bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

abstract class PhaseUploadStore {
  Future<List<Map<String, dynamic>>> list();
  Future<void> save(String id, Map<String, dynamic> value);
  Future<void> remove(String id);
}

class EncryptedPhaseUploadStore implements PhaseUploadStore {
  final LocalDiaryRepository _repository = LocalDiaryRepository();
  @override
  Future<List<Map<String, dynamic>>> list() => _repository.listPhaseUploads();
  @override
  Future<void> save(String id, Map<String, dynamic> value) =>
      _repository.savePhaseUpload(id, value);
  @override
  Future<void> remove(String id) => _repository.removePhaseUpload(id);
}

/// Metadata only. Full snapshots coalesce offline; exact ACKs acknowledge one
/// revision. A new process never invents continuity with its predecessor.
class SourcePhaseUploadService extends ChangeNotifier {
  SourcePhaseUploadService(
      {required this.store,
      required this.transport,
      required this.preferences,
      required Stream<SoundClassificationFrame> frames,
      required Stream<SoundSourceActivitySnapshot> activity,
      bool Function()? historyEnabled,
      DateTime Function()? now})
      : _historyEnabled = historyEnabled ?? (() => true),
        _now = now ?? DateTime.now {
    _frames = frames.listen(_onFrame);
    _activity = activity.listen((s) {
      if (s.isFinal) unawaited(stopCapture());
    });
  }
  static const setting = 'private_phase_upload_v1';
  static const maxIntervals = 20000;
  final PhaseUploadStore store;
  final PhaseUploadTransport transport;
  final SharedPreferences preferences;
  final bool Function() _historyEnabled;
  final DateTime Function() _now;
  late StreamSubscription<SoundClassificationFrame> _frames;
  late StreamSubscription<SoundSourceActivitySnapshot> _activity;
  Timer? _timer;
  Future<void> _work = Future.value();
  bool _initialized = false, _enabled = false, _disposed = false;
  String? _destination, _device;
  String _session = const Uuid().v4();
  int _enabledAt = 0;
  MultiSourceTracker _tracker = MultiSourceTracker();
  final Map<String, AcousticEvidence> _evidence = {};
  final List<AcousticInterval> _coverage = [];
  final Map<String, Map<String, dynamic>> _records = {};
  final Map<String, Map<String, dynamic>> _staging = {};
  Object? error;
  bool get enabled => _enabled;
  bool get destinationMatches =>
      _destination == transport.baseUrl && _device == transport.deviceId;
  int get pendingCount => {
        ..._records.values
            .where((r) =>
                r['delete_pending'] == true ||
                (r['body'] as Map)['revision'] != r['acked_revision'])
            .map((r) => r['id']),
        ..._staging.keys,
      }.length;
  int get acknowledgedCount => _records.values
      .where((r) =>
          r['delete_pending'] != true &&
          (r['body'] as Map)['revision'] == r['acked_revision'])
      .length;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _serial(Future<void> Function() action) {
    final result = _work.then((_) => action());
    _work = result.catchError((Object e) {
      error = e;
      _notify();
    });
    // Keep stream/timer callbacks from producing unhandled errors. Error is
    // visible and records remain pending; it is never represented as an ACK.
    return _work;
  }

  Future<void> initialize({bool automatic = true}) async {
    try {
      for (final record in await store.list()) {
        if (record['format'] != 1 ||
            record['id'] == null ||
            record['body'] is! Map) {
          throw StateError('Invalid encrypted phase queue');
        }
        _records[record['id'] as String] = record;
      }
      for (final old in _records.values.toList()) {
        final body = Map<String, dynamic>.from(old['body'] as Map);
        if (old['delete_pending'] != true && body['state'] == 'open') {
          body['revision'] = (body['revision'] as int) + 1;
          body['state'] = 'interrupted';
          body['end_reason'] = 'process_restart';
          final updated = {...old, 'body': body};
          await store.save(old['id'] as String, updated);
          _records[old['id'] as String] = updated;
        }
      }
      final raw = preferences.getString(setting);
      if (raw != null) {
        final config = jsonDecode(raw) as Map<String, dynamic>;
        _enabled = config['enabled'] == true;
        _destination = config['destination'] as String?;
        _device = config['device'] as String?;
      }
      _enabledAt = _now().millisecondsSinceEpoch;
      _initialized = true;
      if (automatic)
        _timer = Timer.periodic(
            const Duration(seconds: 30), (_) => unawaited(checkpointAndSync()));
      _notify();
    } catch (e) {
      error = e;
      _enabled = false;
      _notify();
    }
  }

  Future<void> setEnabled(bool value) async {
    if (!_initialized) throw StateError('Phase queue unavailable');
    // Pause synchronously, including a request still preparing credentials.
    _enabled = false;
    await stopCapture(reason: 'consent_stopped');
    if (value && !_historyEnabled())
      throw StateError('Enable private history first');
    final device = value ? await transport.ensureDeviceId() : _device;
    final destination = value ? transport.baseUrl : _destination;
    if (!await preferences.setString(
        setting,
        jsonEncode({
          'enabled': value,
          'destination': destination,
          'device': device,
        }))) throw StateError('Upload choice could not be saved');
    _destination = destination;
    _device = device;
    _enabledAt = _now().millisecondsSinceEpoch;
    _session = const Uuid().v4();
    _enabled = value;
    _notify();
  }

  void _record(Iterable<SoundSourceActivitySnapshot> snapshots) {
    for (final snapshot in snapshots) {
      for (final s in [snapshot.lastCompletedSegment, snapshot.activeSegment]) {
        if (s == null) continue;
        final start = math.max(s.start.millisecondsSinceEpoch, _enabledAt);
        final end = s.end.millisecondsSinceEpoch;
        if (end > start)
          _evidence['${s.category}:$start'] =
              AcousticEvidence(start, end, s.category);
      }
    }
  }

  void _onFrame(SoundClassificationFrame frame) {
    if (!_initialized || !_enabled) return;
    // Do not derive an uploaded hint from a window containing pre-consent PCM.
    if (frame.windowStart.millisecondsSinceEpoch < _enabledAt) return;
    if (!_historyEnabled() || !destinationMatches) {
      unawaited(stopCapture(
          reason: !destinationMatches ? 'backend_changed' : 'consent_stopped'));
      return;
    }
    final start =
        math.max(frame.windowStart.millisecondsSinceEpoch, _enabledAt);
    final end = frame.windowEnd.millisecondsSinceEpoch;
    if (end <= start || (_coverage.isNotEmpty && end <= _coverage.last.end))
      return;
    _record(_tracker.add(frame));
    if (_coverage.isNotEmpty && start <= _coverage.last.end) {
      _coverage[_coverage.length - 1] =
          AcousticInterval(_coverage.last.start, end);
    } else {
      _coverage.add(AcousticInterval(start, end));
    }
  }

  List<Map<String, dynamic>> _snapshots({String? finalReason}) {
    if (_coverage.isEmpty) return [];
    // Wait beyond frame hysteresis before publishing boundaries. A candidate
    // still awaiting its second frame cannot move an already uploaded start.
    final until = _coverage.last.end - (finalReason == null ? 2000 : 0);
    final coverage = _coverage
        .where((w) => w.start < until)
        .map((w) => AcousticInterval(w.start, math.min(w.end, until)))
        .toList();
    final phases =
        buildAcousticPhases(evidence: _evidence.values, coverage: coverage);
    return phases.map((p) {
      final id = const Uuid()
          .v5(Uuid.NAMESPACE_URL, '$_session:${p.family}:${p.start}');
      var reason = p.endReason;
      if (reason == 'end_of_observations' && finalReason != null)
        reason = finalReason;
      final state = reason == 'end_of_observations'
          ? 'open'
          : ['inference_gap', 'process_restart', 'backend_changed']
                  .contains(reason)
              ? 'interrupted'
              : 'closed';
      return <String, dynamic>{
        'format': 1,
        'id': id,
        'destination': _destination,
        'device': _device,
        'acked_revision': 0,
        'delete_pending': false,
        'body': <String, dynamic>{
          'phase_id': id,
          'revision': 1,
          'algorithm': AcousticPhasePolicy.version,
          'source_model': 'yamnet_tflite_4d8b4a53',
          'family': p.family,
          'start_ms': p.start,
          'end_ms': p.end,
          'observed_until_ms': until,
          'active_ms': p.activeMs,
          'pause_ms': p.pauseMs,
          'activity': p.activity.map((i) => i.toJson()).toList(),
          'state': state,
          'end_reason': reason
        }
      };
    }).toList();
  }

  Future<void> _persist(List<Map<String, dynamic>> snapshots) async {
    for (final record in snapshots) {
      final body = record['body'] as Map<String, dynamic>;
      if ((body['activity'] as List).length > maxIntervals) {
        throw StateError(
            'Phase is too detailed for upload; local history remains available');
      }
      final id = record['id'] as String, old = _records[record['id']];
      if (old != null) {
        final prior = Map<String, dynamic>.from(old['body'] as Map);
        if (old['delete_pending'] == true || prior['state'] != 'open') continue;
        body['revision'] = prior['revision'];
        if (jsonEncode(_canonical(body)) == jsonEncode(_canonical(prior)))
          continue;
        body['revision'] = (prior['revision'] as int) + 1;
        record['acked_revision'] = old['acked_revision'];
      }
      await store.save(id, record);
      _records[id] = record;
    }
  }

  Future<void> stopCapture({String reason = 'sensor_stopped'}) {
    _record(_tracker.finish());
    final snapshots = _snapshots(finalReason: reason);
    _stage(snapshots);
    _tracker = MultiSourceTracker();
    _coverage.clear();
    _evidence.clear();
    _session = const Uuid().v4();
    return _serial(() async {
      await _flushStaging();
      _notify();
    });
  }

  Future<void> _flushStaging() async {
    while (_staging.isNotEmpty) {
      final record = _staging.values.first;
      await _persist([record]);
      final id = record['id'] as String;
      if (identical(_staging[id], record)) _staging.remove(id);
    }
  }

  void _stage(List<Map<String, dynamic>> snapshots) {
    for (final record in snapshots) {
      final id = record['id'] as String;
      final old = _staging[id];
      if (old != null && (old['body'] as Map)['state'] != 'open') continue;
      _staging[id] = record;
    }
  }

  Future<void> checkpointAndSync() {
    final snapshots = _snapshots();
    _stage(snapshots);
    return _serial(() async {
      await _flushStaging();
      await _sendPending();
      error = null;
      _notify();
    });
  }

  Future<void> _sendPending() async {
    for (final saved in _records.values.toList()) {
      final id = saved['id'] as String;
      final deletion = saved['delete_pending'] == true;
      final body = Map<String, dynamic>.from(saved['body'] as Map);
      if (!deletion && body['revision'] == saved['acked_revision']) continue;
      final destination = saved['destination'] as String,
          device = saved['device'] as String;
      bool permitted() =>
          destination == transport.baseUrl &&
          device == transport.deviceId &&
          (deletion || (_enabled && _historyEnabled() && destinationMatches));
      if (!permitted()) continue;
      await transport.preparePhaseUpload(destination, device);
      if (!permitted()) continue;
      final response = deletion
          ? await transport.deleteSourcePhase(
              destination, device, id, permitted)
          : await transport.putSourcePhase(
              destination, device, body, permitted);
      if (response['phase_id'] != id ||
          response['device_id'] != device ||
          response['status'] !=
              (deletion ? 'deleted' : 'acknowledged_by_server') ||
          (!deletion &&
              (response['revision'] != body['revision'] ||
                  response['digest'] != await phasePayloadDigest(body)))) {
        throw StateError(
            'Phase acknowledgement does not match the saved revision');
      }
      if (deletion) {
        await store.remove(id);
        _records.remove(id);
      } else {
        final acknowledged = {...saved, 'acked_revision': body['revision']};
        await store.save(id, acknowledged);
        _records[id] = acknowledged;
      }
    }
  }

  /// Explicit remote erasure also stops collection; pending PUTs cannot revive
  /// deleted phases because the server keeps content-free deletion tombstones.
  Future<void> deleteRemotePhases() async {
    await setEnabled(false);
    await _serial(() async {
      for (final old in _records.values.toList()) {
        if (old['destination'] != transport.baseUrl ||
            old['device'] != transport.deviceId) continue;
        final tombstone = {
          ...old,
          'delete_pending': true,
          'body': <String, dynamic>{}
        };
        await store.save(old['id'] as String, tombstone);
        _records[old['id'] as String] = tombstone;
      }
      await _sendPending();
      _notify();
    });
  }

  Future<void> get settled => _work;
  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _frames.cancel();
    _activity.cancel();
    super.dispose();
  }
}
