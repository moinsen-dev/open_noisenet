import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/event_detection_service.dart';
import 'package:noisenet_mobile/core/models/api_models.dart' as api;
import 'package:noisenet_mobile/features/noise_monitoring/data/models/noise_event_model.dart'
    as local;

void main() {
  test('detected events do not claim unmeasured A-weighting or sample rate',
      () {
    final start = DateTime.utc(2026, 11, 3);
    final event = NoiseEvent(
      startTime: start,
      endTime: start.add(const Duration(seconds: 30)),
      averageLeqDb: 68,
      maxLevelDb: 70,
      minLevelDb: 60,
      samples: const [60, 70],
      totalSampleCount: 1500,
    );
    final model = local.NoiseEventModel.fromDetectedEvent(
      event,
      eventUuid: 'unweighted-event',
      deviceId: 'device',
    );

    expect(model.samplesCount, 1500);
    expect(model.laeqDb, isNull);
    expect(model.toJson()['laeq_db'], isNull);
    expect(model.eventMetadata?['sample_interval'], isNull);
    expect(model.eventMetadata?['sample_timing'], 'variable_buffer_intervals');
    expect(model.eventMetadata?['level_method'], 'pcm_rms_unweighted_v1');
  });

  test('serializes device-local event times as explicit UTC', () {
    final localStart = DateTime(2026, 8, 18, 18, 9, 41);
    final localEnd = localStart.add(const Duration(seconds: 30));
    final model = local.NoiseEventModel(
      eventUuid: 'utc-test-event',
      deviceId: 'utc-test-device',
      timestampStart: localStart,
      timestampEnd: localEnd,
      leqDb: 68,
      analysisUpdatedAt: localEnd,
    );

    final json = model.toJson();

    expect(json['timestamp_start'], localStart.toUtc().toIso8601String());
    expect(json['timestamp_end'], localEnd.toUtc().toIso8601String());
    expect(json['analysis_updated_at'], localEnd.toUtc().toIso8601String());
    expect((json['timestamp_start'] as String).endsWith('Z'), isTrue);
  });

  test('serializes API submission event times as explicit UTC', () {
    final localStart = DateTime(2026, 8, 18, 18, 9, 41);
    final localEnd = localStart.add(const Duration(seconds: 30));
    final model = api.NoiseEventModel(
      eventUuid: 'api-utc-test-event',
      deviceId: 'api-utc-test-device',
      timestampStart: localStart,
      timestampEnd: localEnd,
      leqDb: 68,
      analysisUpdatedAt: localEnd,
    );

    final json = model.toJson();

    expect(json['timestamp_start'], localStart.toUtc().toIso8601String());
    expect(json['timestamp_end'], localEnd.toUtc().toIso8601String());
    expect(json['analysis_updated_at'], localEnd.toUtc().toIso8601String());
    expect((json['timestamp_start'] as String).endsWith('Z'), isTrue);
  });
}
