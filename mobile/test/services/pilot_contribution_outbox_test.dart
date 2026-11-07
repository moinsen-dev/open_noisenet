import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/api_client_service.dart';
import 'package:noisenet_mobile/services/map_pilot/pilot_consent_controller.dart';
import 'package:noisenet_mobile/services/map_pilot/pilot_contribution_outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryStore implements PilotOutboxStore {
  final rows = <String, Map<String, dynamic>>{};
  @override
  Future<void> clear() async => rows.clear();
  @override
  Future<List<Map<String, dynamic>>> list() async => rows.values.toList();
  @override
  Future<void> remove(String id) async {
    rows.remove(id);
  }

  @override
  Future<void> acknowledge(String id, Map<String, dynamic> record) async {
    if (rows.containsKey(id)) rows[id] = {...record, 'acked': true};
  }

  @override
  Future<void> save(String id, Map<String, Object?> payload) async {
    if (rows.containsKey(id)) throw StateError('Duplicate day');
    rows[id] = Map<String, dynamic>.from(payload);
  }
}

class SyntheticApi implements ApiClientService {
  bool offline = false;
  int uploads = 0;
  @override
  int get credentialEpoch => 0;
  @override
  String get baseUrl => 'https://pilot.example/api/v1';
  @override
  bool get isAuthenticated => true;
  @override
  Future<String> mapPilotIdentity(String destination) async =>
      '00000000-0000-0000-0000-000000000002';
  @override
  Future<Map<String, dynamic>> enableMapPilot(String destination) async =>
      {'enabled': true, 'generation': '00000000-0000-0000-0000-000000000001'};
  @override
  Future<void> withdrawMapPilot(String destination,
      {String? expectedGeneration}) async {}
  @override
  Future<void> uploadMapPilotContribution(String destination,
      Map<String, dynamic> contribution, bool Function() permitted) async {
    if (!permitted() || offline) throw StateError('synthetic offline');
    uploads++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('outbox rejects old days, retains offline work and clears on withdrawal',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = MemoryStore();
    final api = SyntheticApi();
    final consent = PilotConsentController(prefs, api,
        clearOutbox: store.clear, now: () => DateTime.utc(2026, 11, 1, 10));
    var quality = true;
    final outbox = PilotContributionOutbox(
        store: store,
        api: api,
        consent: consent,
        qualityReady: () => quality,
        now: () => DateTime.utc(2026, 11, 3));
    const generation = '00000000-0000-0000-0000-000000000001';
    Future<void> enqueue(String day) => outbox.enqueue(
        destination: api.baseUrl,
        generation: generation,
        day: day,
        band: 'medium');
    await expectLater(enqueue('2026-11-02'), throwsStateError);
    await consent.enable(api.baseUrl);
    await expectLater(enqueue('2026-11-01'), throwsStateError);
    await expectLater(enqueue('2026-11-03'), throwsStateError);
    quality = false;
    await expectLater(enqueue('2026-11-02'), throwsStateError);
    quality = true;
    await enqueue('2026-11-02');
    api.offline = true;
    expect(await outbox.sync(), 0);
    expect(store.rows, hasLength(1));
    api.offline = false;
    expect(await outbox.sync(), 1);
    expect(store.rows.values.single['acked'], isTrue);
    await expectLater(enqueue('2026-11-02'), throwsStateError);
    expect(await outbox.sync(), 0);
    expect(await consent.withdraw(), isTrue);
    expect(store.rows, isEmpty);
    expect(await outbox.sync(), 0);
    expect(api.uploads, 1);
  });
}
