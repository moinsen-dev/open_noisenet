import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../features/noise_diary/data/diary_repository.dart';
import '../api_client_service.dart';
import 'pilot_consent_controller.dart';

abstract class PilotOutboxStore {
  Future<List<Map<String, dynamic>>> list();
  Future<void> save(String id, Map<String, Object?> payload);
  Future<void> remove(String id);
  Future<void> acknowledge(String id, Map<String, dynamic> record);
  Future<void> clear();
}

class EncryptedPilotOutboxStore implements PilotOutboxStore {
  final LocalDiaryRepository _repository = LocalDiaryRepository();
  Future<void> _work = Future.value();

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _work = _work.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  @override
  Future<List<Map<String, dynamic>>> list() =>
      _serial(_repository.listPilotContributions);
  @override
  Future<void> save(String id, Map<String, Object?> payload) =>
      _serial(() => _repository.savePilotContribution(id, payload));
  @override
  Future<void> remove(String id) =>
      _serial(() => _repository.removePilotContribution(id));
  @override
  Future<void> acknowledge(String id, Map<String, dynamic> record) =>
      _serial(() => _repository.acknowledgePilotContribution(id, record));
  @override
  Future<void> clear() => _serial(_repository.clearPilotContributions);
}

/// Not registered in the app. No real measurement path currently passes the
/// independently verified quality gate required by the caller.
class PilotContributionOutbox {
  PilotContributionOutbox(
      {required this.store,
      required this.api,
      required this.consent,
      required this.qualityReady,
      DateTime Function()? now})
      : _now = now ?? DateTime.now;
  final PilotOutboxStore store;
  final ApiClientService api;
  final PilotConsentController consent;
  final bool Function() qualityReady;
  final DateTime Function() _now;
  bool _syncing = false;

  DateTime _day(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value))
      throw ArgumentError('Invalid UTC day');
    final result = DateTime.tryParse('${value}T00:00:00Z');
    if (result == null || result.toIso8601String().substring(0, 10) != value)
      throw ArgumentError('Invalid UTC day');
    return result;
  }

  Future<void> enqueue(
      {required String destination,
      required String generation,
      required String day,
      required String band}) async {
    final start = consent.sessionStartedAtUtc;
    final date = _day(day);
    final now = _now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    if (!qualityReady() ||
        start == null ||
        !consent.permits(destination, generation) ||
        !const {'low', 'medium', 'high'}.contains(band) ||
        !date.isAfter(DateTime.utc(start.year, start.month, start.day)) ||
        date.isBefore(today.subtract(const Duration(days: 30))) ||
        !date.isBefore(today)) {
      throw StateError('Pilot contribution is not eligible');
    }
    // One immutable record per server, consent generation and UTC day.
    final id = const Uuid()
        .v5(Uuid.NAMESPACE_URL, '$destination\u0000$generation\u0000$day');
    await store.save(id, {
      'id': id,
      'destination': destination,
      'generation': generation,
      'day': day,
      'cell_id': 'hamburg-eimsbuettel',
      'level_band': band
    });
  }

  Future<int> sync() async {
    if (_syncing || !qualityReady()) return 0;
    _syncing = true;
    var acknowledged = 0;
    try {
      for (final record in await store.list()) {
        final id = record['id'];
        final destination = record['destination'];
        final generation = record['generation'];
        final day = record['day'];
        final band = record['level_band'];
        if (id is! String ||
            destination is! String ||
            generation is! String ||
            day is! String ||
            band is! String ||
            (record.containsKey('acked') && record['acked'] is! bool) ||
            !const {'low', 'medium', 'high'}.contains(band) ||
            record['cell_id'] != 'hamburg-eimsbuettel') {
          throw StateError('Invalid encrypted pilot outbox');
        }
        _day(day);
        if (id !=
            const Uuid().v5(Uuid.NAMESPACE_URL,
                '$destination\u0000$generation\u0000$day')) {
          throw StateError('Invalid encrypted pilot outbox identity');
        }
        if (record['acked'] == true) continue;
        if (!qualityReady() || !consent.permits(destination, generation)) break;
        try {
          await api.uploadMapPilotContribution(
              destination,
              {
                'generation': generation,
                'day': day,
                'cell_id': 'hamburg-eimsbuettel',
                'level_band': band
              },
              () => qualityReady() && consent.permits(destination, generation));
        } catch (_) {
          break;
        }
        await store.acknowledge(id, record);
        acknowledged++;
      }
      return acknowledged;
    } finally {
      _syncing = false;
    }
  }
}
