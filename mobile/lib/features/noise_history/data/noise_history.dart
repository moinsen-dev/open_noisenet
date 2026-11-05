import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/models/noise_measurement.dart';
import '../../../services/sound_analysis/sound_analysis_models.dart';
import '../../noise_diary/data/diary_repository.dart';

class SourceHistoryEntry {
  const SourceHistoryEntry(
      {required this.id,
      required this.category,
      required this.start,
      required this.end,
      required this.confidence});
  final String id;
  final String category;
  final DateTime start;
  final DateTime end;
  final double confidence;

  Map<String, Object?> toMap() => {
        'id': id,
        'category': category,
        'start': start.toUtc().millisecondsSinceEpoch,
        'end': end.toUtc().millisecondsSinceEpoch,
        'confidence': confidence
      };

  factory SourceHistoryEntry.fromMap(Map<String, dynamic> map) {
    final result = SourceHistoryEntry(
        id: map['id'] as String,
        category: map['category'] as String,
        start: DateTime.fromMillisecondsSinceEpoch(map['start'] as int,
            isUtc: true),
        end:
            DateTime.fromMillisecondsSinceEpoch(map['end'] as int, isUtc: true),
        confidence: (map['confidence'] as num).toDouble());
    if (result.id.isEmpty ||
        !OpenNoiseCategory.values.contains(result.category) ||
        !result.end.isAfter(result.start) ||
        !result.confidence.isFinite ||
        result.confidence < 0 ||
        result.confidence > 1) {
      throw const FormatException('Invalid source history record');
    }
    return result;
  }
}

abstract class SourceHistoryStore {
  Future<void> save(SourceHistoryEntry entry);
  Future<List<SourceHistoryEntry>> list();
  Future<void> clear();
}

class EncryptedSourceHistoryStore implements SourceHistoryStore {
  EncryptedSourceHistoryStore([LocalDiaryRepository? repository])
      : _repository = repository ?? LocalDiaryRepository();
  final LocalDiaryRepository _repository;
  @override
  Future<void> save(SourceHistoryEntry entry) =>
      _repository.saveSourceHistory(entry.id, entry.toMap());
  @override
  Future<List<SourceHistoryEntry>> list() async =>
      (await _repository.listSourceHistory())
          .map(SourceHistoryEntry.fromMap)
          .toList();
  @override
  Future<void> clear() => _repository.clearSourceHistory();
}

/// Records only structured model hints; audio and speech content never enter it.
/// Active segments are checkpointed at most once per 30 s and on completion.
class SoundHistoryCollector extends ChangeNotifier {
  SoundHistoryCollector(
      {required this.store,
      required this.preferences,
      required Stream<SoundSourceActivitySnapshot> activity,
      DateTime Function()? now})
      : _now = now ?? DateTime.now {
    _enabled = preferences.getBool(_setting) ?? false;
    _enabledAt = _now();
    _subscription = activity.listen(_onActivity);
  }
  static const _setting = 'private_source_history_enabled_v1';
  final SourceHistoryStore store;
  final SharedPreferences preferences;
  final DateTime Function() _now;
  late StreamSubscription<SoundSourceActivitySnapshot> _subscription;
  late bool _enabled;
  late DateTime _enabledAt;
  Future<void> _pending = Future.value();
  final Map<String, String> _ids = {};
  final Map<String, DateTime> _savedUntil = {};
  String? _lastCompleted;
  Object? error;
  bool get enabled => _enabled;

  Future<void> setEnabled(bool enabled) async {
    if (!enabled) {
      _enabled = false;
      await flush();
    }
    if (!await preferences.setBool(_setting, enabled)) {
      throw StateError('History setting was not saved');
    }
    _enabledAt = _now();
    _ids.clear();
    _savedUntil.clear();
    _lastCompleted = null;
    _enabled = enabled;
    notifyListeners();
  }

  void _onActivity(SoundSourceActivitySnapshot snapshot) {
    if (!_enabled) return;
    final completed = snapshot.lastCompletedSegment;
    if (completed != null) {
      final signature = _signature(completed);
      if (_lastCompleted != signature) {
        _lastCompleted = signature;
        _record(completed, completed: true);
      }
    }
    final active = snapshot.activeSegment;
    if (active != null) _record(active, completed: false);
  }

  String _signature(SoundSourceSegment segment) =>
      '${segment.start.microsecondsSinceEpoch}:${segment.category}';

  void _record(SoundSourceSegment segment, {required bool completed}) {
    if (!segment.end.isAfter(_enabledAt) ||
        !OpenNoiseCategory.values.contains(segment.category) ||
        segment.category == OpenNoiseCategory.unknownSoundSource ||
        !segment.confidence.isFinite ||
        segment.confidence < 0 ||
        segment.confidence > 1) return;
    final signature = _signature(segment);
    final previous = _savedUntil[signature];
    if (!completed &&
        previous != null &&
        segment.end.difference(previous) < const Duration(seconds: 30)) return;
    final start =
        segment.start.isBefore(_enabledAt) ? _enabledAt : segment.start;
    if (!segment.end.isAfter(start)) return;
    final entry = SourceHistoryEntry(
        id: _ids.putIfAbsent(signature, () => const Uuid().v4()),
        category: segment.category,
        start: start,
        end: segment.end,
        confidence: segment.confidence);
    _savedUntil[signature] = segment.end;
    _pending = _pending.then((_) async {
      try {
        await store.save(entry);
        if (error != null) {
          error = null;
          notifyListeners();
        }
      } catch (exception) {
        error = exception;
        notifyListeners();
      }
    });
    if (completed) {
      _ids.remove(signature);
      _savedUntil.remove(signature);
    }
  }

  Future<void> flush() => _pending;

  /// Prevent queued writes from reappearing after a user-initiated clear.
  Future<void> clear() async {
    final wasEnabled = _enabled;
    _enabled = false;
    try {
      await flush();
      await store.clear();
      _ids.clear();
      _savedUntil.clear();
      _lastCompleted = null;
      _enabledAt = _now();
      error = null;
    } finally {
      _enabled = wasEnabled;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Source hints up to one minute apart are grouped without implying continuous
/// sound; the measured active duration and time span remain separate.
class SourceHistoryBlock {
  SourceHistoryBlock(this.entries);
  final List<SourceHistoryEntry> entries;
  String get category => entries.first.category;
  DateTime get start => entries.first.start;
  DateTime get end =>
      entries.map((e) => e.end).reduce((a, b) => a.isAfter(b) ? a : b);
  Duration get span => end.difference(start);
  Duration get detected => Duration(
      microseconds: entries.fold(
          0, (sum, e) => sum + e.end.difference(e.start).inMicroseconds));
  int get gaps => math.max(0, entries.length - 1);
}

List<SourceHistoryBlock> groupSourceHistory(List<SourceHistoryEntry> entries,
    {Duration maxGap = const Duration(minutes: 1)}) {
  final sorted = [...entries]..sort((a, b) => a.start.compareTo(b.start));
  final result = <SourceHistoryBlock>[];
  for (final entry in sorted) {
    if (result.isNotEmpty &&
        result.last.category == entry.category &&
        !entry.start.isBefore(result.last.end) &&
        entry.start.difference(result.last.end) <= maxGap) {
      result.last.entries.add(entry);
    } else {
      result.add(SourceHistoryBlock([entry]));
    }
  }
  return result.reversed.toList();
}

/// Minutes are mixed scene aggregates, not levels attributed to one source.
List<NoiseMeasurement> overlappingMinutes(
        SourceHistoryBlock block, List<NoiseMeasurement> measurements) =>
    unambiguousMinutes(measurements).where((m) {
      final start =
          DateTime.fromMillisecondsSinceEpoch(m.timestamp * 1000, isUtc: true);
      return start.isBefore(block.end) &&
          start.add(const Duration(minutes: 1)).isAfter(block.start);
    }).toList();

/// Repeated clock minutes can reflect overlapping recording sessions. Their
/// provenance cannot be inferred, so exclude them instead of inventing an
/// uninterrupted interval or attributing one ambiguous level to a source.
List<NoiseMeasurement> unambiguousMinutes(List<NoiseMeasurement> measurements) {
  final counts = <int, int>{};
  for (final measurement in measurements) {
    counts.update(measurement.timestamp, (count) => count + 1,
        ifAbsent: () => 1);
  }
  return measurements.where((m) => counts[m.timestamp] == 1).toList();
}

class LevelHistoryBlock {
  LevelHistoryBlock(this.minutes, {this.threshold = double.negativeInfinity});
  final List<NoiseMeasurement> minutes;
  final double threshold;
  DateTime get start =>
      DateTime.fromMillisecondsSinceEpoch(minutes.first.timestamp * 1000,
          isUtc: true);
  DateTime get end =>
      DateTime.fromMillisecondsSinceEpoch((minutes.last.timestamp + 60) * 1000,
          isUtc: true);
  Duration get duration => end.difference(start);
  double get highestMinute => minutes.map((m) => m.leqDb).reduce(math.max);
  int get activeMinutes => minutes.where((m) => m.leqDb >= threshold).length;
  int get pauseMinutes => minutes.length - activeMinutes;
  int get pauseCount {
    var count = 0;
    var inPause = false;
    for (final minute in minutes) {
      if (minute.leqDb < threshold) {
        if (!inPause) count++;
        inPause = true;
      } else {
        inPause = false;
      }
    }
    return count;
  }

  double get averageMinute =>
      10 *
      math.log(minutes.fold<double>(
              0, (sum, m) => sum + math.pow(10, m.leqDb / 10)) /
          minutes.length) /
      math.ln10;
}

/// Maximal episodes connected by observed, bounded quiet gaps. Missing,
/// duplicate or invalid minutes always split an episode.
/// Leading/trailing quiet minutes are never counted. This is an analysis view,
/// not a claim of continuous sound or a verified cause/disturbance.
List<LevelHistoryBlock> groupLevelHistory(List<NoiseMeasurement> measurements,
    {required double threshold, int maxPauseMinutes = 2}) {
  if (!threshold.isFinite || maxPauseMinutes < 0) {
    throw ArgumentError(
        'A finite threshold and nonnegative pause are required');
  }
  final sorted = unambiguousMinutes(measurements)
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final result = <LevelHistoryBlock>[];
  var current = <NoiseMeasurement>[];
  var pending = <NoiseMeasurement>[];
  NoiseMeasurement? previous;
  void finish() {
    if (current.isNotEmpty) {
      result.add(LevelHistoryBlock(current, threshold: threshold));
    }
    current = [];
    pending = [];
  }

  for (final measurement in sorted) {
    if (previous != null && measurement.timestamp != previous.timestamp + 60) {
      finish();
    }
    previous = measurement;
    if (!measurement.leqDb.isFinite ||
        (measurement.samplesCount ?? 1) <= 0 ||
        measurement.timestamp % 60 != 0) {
      finish();
      continue;
    }
    if (measurement.leqDb >= threshold) {
      current.addAll(pending);
      pending = [];
      current.add(measurement);
    } else if (current.isNotEmpty) {
      pending.add(measurement);
      if (pending.length > maxPauseMinutes) finish();
    }
  }
  finish();
  return result.reversed.toList();
}

/// Union of the clipped intervals, so overlapping model hints do not inflate
/// the displayed coverage. Coverage is evidence availability, not accuracy.
Duration sourceCoverage(
    LevelHistoryBlock block, List<SourceHistoryEntry> entries) {
  final intervals = overlappingSources(block, entries)
      .map((e) => (
            e.start.isBefore(block.start) ? block.start : e.start,
            e.end.isAfter(block.end) ? block.end : e.end,
          ))
      .toList()
    ..sort((a, b) => a.$1.compareTo(b.$1));
  DateTime? start, end;
  var total = Duration.zero;
  for (final interval in intervals) {
    if (end == null || interval.$1.isAfter(end)) {
      if (start != null) total += end!.difference(start);
      start = interval.$1;
      end = interval.$2;
    } else if (interval.$2.isAfter(end)) {
      end = interval.$2;
    }
  }
  if (start != null) total += end!.difference(start);
  return total;
}

List<SourceHistoryEntry> overlappingSources(
        LevelHistoryBlock block, List<SourceHistoryEntry> entries) =>
    entries
        .where((e) => e.start.isBefore(block.end) && e.end.isAfter(block.start))
        .toList();
