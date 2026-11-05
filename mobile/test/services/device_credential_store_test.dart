import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/device_credential_store.dart';

void main() {
  test('keys are random, persisted before use and scoped to backend and device', () async {
    final values = <String, String>{};
    final store = DeviceCredentialStore(
      read: (key) async => values[key],
      write: (key, value) async { values[key] = value; },
    );
    expect(await store.get('https://one.example/api', 'sensor', create: false), isNull);
    final first = await store.get('https://one.example/api', 'sensor', create: true);
    expect(first, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    expect(await store.get('https://one.example/api', 'sensor'), first);
    final otherServer = await store.get('https://two.example/api', 'sensor', create: true);
    final otherDevice = await store.get('https://one.example/api', 'other', create: true);
    expect(otherServer, isNot(first));
    expect(otherDevice, isNot(first));
  });

  test('concurrent registration requests share one credential', () async {
    final values = <String, String>{};
    var writes = 0;
    final store = DeviceCredentialStore(
      read: (key) async => values[key],
      write: (key, value) async {
        writes++;
        values[key] = value;
      },
    );
    final keys = await Future.wait(List.generate(8, (_) =>
        store.get('https://one.example/api', 'sensor', create: true)));
    expect(keys.toSet(), hasLength(1));
    expect(writes, 1);
  });

  test('does not return a newly generated key if secure storage fails', () async {
    final store = DeviceCredentialStore(
      read: (_) async => null,
      write: (_, __) async => throw StateError('storage unavailable'),
    );
    await expectLater(store.get('https://one.example/api', 'sensor', create: true), throwsStateError);
  });
}
