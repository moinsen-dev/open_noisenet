import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/features/settings/presentation/widgets/audio_calibration_dialog.dart';
import 'package:noisenet_mobile/services/sound_analysis/sound_analysis_models.dart';

void main() {
  testWidgets(
      'compares a full interval and saves an explicitly selected offset',
      (tester) async {
    final frames = StreamController<PcmAudioFrame>.broadcast(sync: true);
    addTearDown(frames.close);
    double? saved;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return Scaffold(
          body: ElevatedButton(
        onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => AudioCalibrationDialog(
                frames: frames.stream,
                captureReady: () => true,
                initialOffset: 0,
                onSave: (value) async {
                  saved = value;
                })),
        child: const Text('Open'),
      ));
    })));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Measure 60 seconds'));
    await tester.pump();
    for (var second = 0; second < 60; second++) {
      frames.add(PcmAudioFrame(
          samples: const [0.25],
          sampleRate: 1,
          capturedAt: DateTime.utc(2026, 1, 1).add(Duration(seconds: second))));
    }
    await tester.pump();
    expect(find.text('Measured: 60 / 60 seconds'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '80');
    await tester.ensureVisible(find.text('Calculate offset'));
    await tester.tap(find.text('Calculate offset'));
    await tester.pump();
    expect(find.textContaining('Suggested offset applied'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved, closeTo(1.732, 0.01));
  });
}
