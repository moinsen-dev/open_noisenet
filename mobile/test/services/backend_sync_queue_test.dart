import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:noisenet_mobile/core/logging/app_logger.dart';
import 'package:noisenet_mobile/core/models/api_models.dart';
import 'package:noisenet_mobile/features/noise_monitoring/data/models/noise_event_model.dart'
    as local;
import 'package:noisenet_mobile/features/noise_monitoring/data/repositories/event_repository.dart';
import 'package:noisenet_mobile/services/api_client_service.dart';
import 'package:noisenet_mobile/services/backend_sync_service.dart';
import 'package:noisenet_mobile/services/sqlite_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';

class _Settings implements SQLitePreferencesService {
  bool forcedOffline = true;
  bool autoSubmission = false;

  @override
  Future<bool> getForceOfflineMode() async => forcedOffline;
  @override
  Future<bool> getAutoSubmissionEnabled() async => autoSubmission;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Api implements ApiClientService {
  int submissions = 0;
  bool failSubmission = true;
  bool failRegistration = false;

  @override
  bool get isAuthenticated => false;
  @override
  Future<bool> isBackendAvailable() async => true;
  @override
  Future<DeviceModel> ensureDeviceRegistered({String? name, double? locationLat,
      double? locationLng, String? address, bool isPublic = false}) async {
    if (failRegistration) throw StateError('registration unavailable');
    return DeviceModel(deviceId: 'test-device', name: 'Test', deviceType: DeviceType.smartphone);
  }
  @override
  Future<EventReceipt?> submitAnonymousEvent(NoiseEventModel event) async {
    submissions++;
    if (failSubmission) throw StateError('simulated network failure');
    final timestamp = DateTime.utc(2026, 1, 1);
    return EventReceipt(
      eventUuid: event.eventUuid!,
      serverEventId: 'server-event-1',
      deviceId: event.deviceId,
      status: 'active',
      receivedAt: timestamp,
      acknowledgedAt: timestamp,
      analysisState: 'not_started',
    );
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppLogger.initialize);

  test('queue survives disabled, offline and failed upload, then acknowledges once', () async {
    final now = DateTime.utc(2026, 1, 1);
    final event = NoiseEventModel(
      eventUuid: 'queued-event-1',
      deviceId: 'test-device',
      timestampStart: now,
      timestampEnd: now.add(const Duration(seconds: 1)),
      leqDb: 60,
    );
    SharedPreferences.setMockInitialValues({
      'queued_events': jsonEncode([event.toJson()]),
    });
    final prefs = await SharedPreferences.getInstance();
    final settings = _Settings();
    final api = _Api();
    final locator = GetIt.instance;
    locator.registerSingleton<SharedPreferences>(prefs);
    locator.registerSingleton<SQLitePreferencesService>(settings);
    locator.registerSingleton<ApiClientService>(api);
    locator.registerSingleton<Talker>(Talker());
    addTearDown(locator.reset);

    final repository = await EventRepository.getInstance();
    await repository.saveEvent(local.NoiseEventModel(
      eventUuid: 'queued-event-1',
      deviceId: 'test-device',
      timestampStart: now,
      timestampEnd: now.add(const Duration(seconds: 1)),
      leqDb: 60,
    ));

    final service = BackendSyncService();
    addTearDown(service.dispose);
    await service.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(service.queuedEventsCount, 1);

    settings.forcedOffline = false;
    expect(await service.syncQueuedEvents(), 0);
    expect(service.queuedEventsCount, 1);
    expect(jsonDecode(prefs.getString('queued_events')!) as List, hasLength(1));

    service.dispose();
    settings.forcedOffline = true;
    final restarted = BackendSyncService();
    addTearDown(restarted.dispose);
    await restarted.initialize();
    expect(restarted.queuedEventsCount, 1);
    expect(await restarted.syncQueuedEvents(), 0);
    expect(api.submissions, 0);

    settings.forcedOffline = false;
    settings.autoSubmission = true;
    api.failRegistration = true;
    expect(await restarted.syncQueuedEvents(), 0);
    expect(restarted.queuedEventsCount, 1);
    expect(api.submissions, 0);
    api.failRegistration = false;
    expect(await restarted.syncQueuedEvents(), 0);
    expect(restarted.queuedEventsCount, 1);
    expect(api.submissions, 1);

    api.failSubmission = false;
    expect(await restarted.syncQueuedEvents(), 1);
    expect(restarted.queuedEventsCount, 0);
    expect(jsonDecode(prefs.getString('queued_events')!) as List, isEmpty);
    final saved = await repository.getEventByUuid('queued-event-1');
    expect(saved?.lifecycleState, local.EventLifecycleState.acknowledgedByServer);
    expect(saved?.serverEventId, 'server-event-1');
    expect(await restarted.syncQueuedEvents(), 0);
    expect(api.submissions, 2);
  });
}
