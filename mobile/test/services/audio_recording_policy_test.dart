import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:noisenet_mobile/services/audio_recording_service.dart';
import 'package:noisenet_mobile/services/recording_service.dart';
import 'package:noisenet_mobile/services/sqlite_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('manual, debug and continuous entrypoints cannot create new audio',
      () async {
    GetIt.instance.registerSingleton<SQLitePreferencesService>(
        SQLitePreferencesService());
    addTearDown(() => GetIt.instance.unregister<SQLitePreferencesService>());
    final manual = AudioRecordingService();
    expect(await manual.startRecording(), isNull);
    expect(await manual.createTestRecording(), isNull);
    final continuous = RecordingService();
    expect(await continuous.startRecording(), isFalse);
    await expectLater(
        continuous.updateSettings(enableContinuousRecording: true),
        throwsStateError);
    expect(continuous.activeBufferCount, 0);
  });
}
