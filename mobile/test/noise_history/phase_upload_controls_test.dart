import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:noisenet_mobile/features/noise_history/data/noise_history.dart';
import 'package:noisenet_mobile/features/noise_history/presentation/noise_history_page.dart';

import '../services/source_phase_upload_test.dart' show Rig;
import 'noise_history_test.dart' show MemoryStore;

void main() {
  testWidgets(
      'upload requires consent, cancellation is inert, erasure is confirmed',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final rig = Rig(prefs);
    await rig.init();
    final collector = SoundHistoryCollector(
        store: MemoryStore(),
        preferences: prefs,
        activity: rig.activity.stream);
    await collector.setEnabled(true);
    addTearDown(() async {
      collector.dispose();
      await rig.close();
    });
    await tester.pumpWidget(MaterialApp(
        home: NoiseHistoryPage(
            collector: collector,
            phaseUploads: rig.service,
            loadMeasurements: () async => [])));
    await tester.pumpAndSettle();
    final toggle = find.widgetWithText(
        SwitchListTile, 'Private Geräuschphasen übertragen');
    await tester.scrollUntilVisible(toggle, 150);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Private Phasen übertragen?'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(rig.service.enabled, isFalse);
    expect(rig.transport.sent, isEmpty);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aktivieren'));
    await tester.pumpAndSettle();
    expect(rig.service.enabled, isTrue);
    rig.feed(0, 30000);
    await tester.runAsync(rig.service.checkpointAndSync);
    await tester.pumpAndSettle();
    expect(find.text('1 aktuelle Stände bestätigt · 0 ausstehend'),
        findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('Übertragene Phasen löschen'), 100);
    await tester.tap(find.text('Übertragene Phasen löschen'));
    await tester.pumpAndSettle();
    expect(find.text('Übertragene Phasen löschen?'), findsOneWidget);
    await tester.tap(find.text('Löschauftrag speichern'));
    await tester.pumpAndSettle();
    // The dialog can settle before asynchronous persistence/erasure finishes.
    // Observe completion without invoking a second sync on behalf of the UI.
    await tester.runAsync(() async {
      for (var attempt = 0;
          attempt < 40 && rig.transport.server.isNotEmpty;
          attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    });
    await tester.pumpAndSettle();
    expect(rig.service.enabled, isFalse);
    expect(rig.transport.server, isEmpty);
    await tester.binding.setSurfaceSize(const Size(320, 780));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
