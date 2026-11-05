import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/logging/app_logger.dart';
import 'open_noise_taxonomy_head.dart';
import 'sound_analysis_models.dart';
import 'sound_scene_aggregator.dart';
import 'sound_source_activity_tracker.dart';
import 'streaming_linear_resampler.dart';
import 'yamnet_inference_engine.dart';

class OnDeviceSoundAnalysisService {
  static const inputSampleRate = 16000;
  static const inputWindowSamples = 15600;
  static const hopSamples = 7680;
  static const labelsAsset = 'assets/models/yamnet_label_list.txt';
  static const _maxBufferedWindows = 5;
  static const maxBufferedPcmSamples =
      inputWindowSamples + (hopSamples * (_maxBufferedWindows - 1));
  static const maxPcmRetentionMilliseconds =
      maxBufferedPcmSamples * 1000 ~/ inputSampleRate;

  final YamnetInferenceEngine _engine;
  final OpenNoiseTaxonomyHead _taxonomyHead;
  final SoundSceneAggregator _sceneAggregator;
  final SoundSourceActivityTracker _sourceActivityTracker;
  final StreamingLinearResampler _resampler;
  final SoundFrameHistory _history;

  final StreamController<SoundClassificationFrame> _resultController =
      StreamController<SoundClassificationFrame>.broadcast();
  final StreamController<SoundSourceActivitySnapshot> _activityController =
      StreamController<SoundSourceActivitySnapshot>.broadcast();
  final List<double> _inferenceBuffer = <double>[];

  StreamSubscription<PcmAudioFrame>? _pcmSubscription;
  List<String> _labels = const [];
  DateTime? _bufferStart;
  DateTime? _lastInferenceAt;
  String? _lastError;
  SoundClassificationFrame? _latestFrame;
  SoundSourceActivitySnapshot? _latestActivity;
  bool _initialized = false;
  bool _running = false;
  bool _draining = false;
  Future<void>? _drainFuture;
  int _inferenceCount = 0;
  int _droppedWindows = 0;
  int _sessionGeneration = 0;

  OnDeviceSoundAnalysisService({
    YamnetInferenceEngine? engine,
    OpenNoiseTaxonomyHead? taxonomyHead,
    SoundSceneAggregator? sceneAggregator,
    SoundSourceActivityTracker? sourceActivityTracker,
    StreamingLinearResampler? resampler,
    SoundFrameHistory? history,
  })  : _engine = engine ?? createYamnetInferenceEngine(),
        _taxonomyHead = taxonomyHead ?? OpenNoiseTaxonomyHead(),
        _sceneAggregator = sceneAggregator ?? const SoundSceneAggregator(),
        _sourceActivityTracker =
            sourceActivityTracker ?? SoundSourceActivityTracker(),
        _resampler = resampler ?? StreamingLinearResampler(),
        _history = history ?? SoundFrameHistory();

  Stream<SoundClassificationFrame> get results => _resultController.stream;
  Stream<SoundSourceActivitySnapshot> get sourceActivity =>
      _activityController.stream;
  bool get isReady => _initialized && _engine.isReady;
  bool get isRunning => _running;
  SoundClassificationFrame? get latestFrame => _latestFrame;
  SoundSourceActivitySnapshot? get latestSourceActivity => _latestActivity;

  Future<bool> initialize() async {
    if (isReady) return true;
    try {
      final labelText = await rootBundle.loadString(labelsAsset);
      final labels = labelText
          .split(RegExp(r'\r?\n'))
          .where((label) => label.isNotEmpty)
          .toList(growable: false);
      if (labels.length != 521) {
        throw StateError(
          'YAMNet label asset contains ${labels.length} labels; expected 521.',
        );
      }

      await _engine.initialize();
      _labels = labels;
      _initialized = true;
      _lastError = null;
      AppLogger.success(
        'On-device sound analysis ready (${_engine.modelVersion})',
      );
      return true;
    } catch (error, stackTrace) {
      _initialized = false;
      _lastError = error.toString();
      AppLogger.error(
        'On-device sound analysis initialization failed',
        error,
        stackTrace,
      );
      return false;
    }
  }

  Future<bool> start(Stream<PcmAudioFrame> pcmFrames) async {
    if (_running) return true;
    if (!await initialize()) return false;

    _resetSessionState(clearHistory: true);
    _sessionGeneration++;
    _pcmSubscription = pcmFrames.listen(
      _handlePcmFrame,
      onError: (Object error, StackTrace stackTrace) {
        _lastError = error.toString();
        AppLogger.error(
            'PCM stream failed during sound analysis', error, stackTrace);
      },
      cancelOnError: false,
    );
    _running = true;
    AppLogger.audio(
      'On-device sound analysis started; PCM remains ephemeral.',
    );
    return true;
  }

  Future<void> stop() async {
    final wasRunning = _running;
    _running = false;
    _sessionGeneration++;
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    await _drainFuture;
    _drainFuture = null;
    if (wasRunning) {
      final finished = _sourceActivityTracker.finish();
      if (finished != null) {
        _publishSourceActivity(finished);
      }
    }
    _resetSessionState(clearHistory: false);
    AppLogger.audio('On-device sound analysis stopped.');
  }

  SoundSceneSummary? summarize({
    required DateTime start,
    required DateTime end,
  }) {
    return _sceneAggregator.summarize(
      frames: _history.frames,
      start: start,
      end: end,
    );
  }

  SoundSceneSummary? summarizeRecent({
    Duration duration = const Duration(seconds: 10),
  }) {
    final end = DateTime.now();
    return summarize(start: end.subtract(duration), end: end);
  }

  List<SoundSourceSegment> sourceSegments({
    required DateTime start,
    required DateTime end,
  }) {
    return _sourceActivityTracker.segmentsOverlapping(
      start: start,
      end: end,
    );
  }

  Map<String, dynamic> getDiagnostics() => {
        'initialized': _initialized,
        'running': _running,
        'model': _engine.modelVersion,
        'taxonomy_head': OpenNoiseTaxonomyHead.version,
        'input_sample_rate_hz': inputSampleRate,
        'window_samples': inputWindowSamples,
        'hop_samples': hopSamples,
        'inference_count': _inferenceCount,
        'dropped_windows': _droppedWindows,
        'structured_history_frames': _history.frames.length,
        'pcm_samples_buffered': _inferenceBuffer.length,
        'last_inference_at': _lastInferenceAt?.toIso8601String(),
        'latest_category': _latestActivity?.activeSegment?.category ??
            OpenNoiseCategory.unknownSoundSource,
        'latest_confidence': _latestActivity?.activeSegment?.confidence ?? 0,
        'latest_candidate_category': _latestFrame?.category,
        'latest_candidate_confidence': _latestFrame?.confidence,
        'latest_category_scores': _latestFrame?.categoryScores,
        'latest_top_yamnet_scores': _latestFrame?.topYamnetScores
            .map((score) => score.toJson())
            .toList(),
        'latest_inference_ms': _latestFrame?.inferenceMs,
        'source_timing_method': SoundSourceActivityTracker.version,
        'source_timing_resolution_ms':
            SoundSourceActivityTracker.frameHopMilliseconds,
        'source_boundary_uncertainty_ms':
            SoundSourceActivityTracker.frameWindowMilliseconds,
        'active_source_category': _latestActivity?.activeSegment?.category,
        'active_source_duration_ms':
            _latestActivity?.activeSegment?.duration.inMilliseconds,
        'completed_source_segments':
            _sourceActivityTracker.completedSegments.length,
        'last_error': _lastError,
        'audio_retention': 'ephemeral_window_only',
        'max_pcm_retention_ms': maxPcmRetentionMilliseconds,
        'speech_recognition': false,
      };

  Future<void> dispose() async {
    await stop();
    await _engine.close();
    await _resultController.close();
    await _activityController.close();
  }

  void _handlePcmFrame(PcmAudioFrame frame) {
    if (!_running || frame.samples.isEmpty) return;

    final resampled = _resampler.process(
      frame.samples,
      inputSampleRate: frame.sampleRate,
    );
    if (resampled.isEmpty) return;

    _bufferStart ??= frame.capturedAt.subtract(
      Duration(
        microseconds: ((resampled.length / inputSampleRate) * 1000000).round(),
      ),
    );
    _inferenceBuffer.addAll(resampled);
    _trimBacklog();

    if (!_draining && _inferenceBuffer.length >= inputWindowSamples) {
      _drainFuture = _drainInferenceWindows(_sessionGeneration);
    }
  }

  Future<void> _drainInferenceWindows(int generation) async {
    if (_draining) return;
    _draining = true;
    try {
      while (_running &&
          generation == _sessionGeneration &&
          _inferenceBuffer.length >= inputWindowSamples) {
        final windowStart = _bufferStart ?? DateTime.now();
        final windowEnd = windowStart.add(
          const Duration(microseconds: 975000),
        );
        final waveform = List<double>.from(
          _inferenceBuffer.take(inputWindowSamples),
          growable: false,
        );

        final stopwatch = Stopwatch()..start();
        try {
          final scores = await _engine.run(waveform);
          stopwatch.stop();
          if (!_running || generation != _sessionGeneration) return;

          final taxonomy = _taxonomyHead.classify(
            yamnetScores: scores,
            labels: _labels,
          );
          final frame = SoundClassificationFrame(
            windowStart: windowStart,
            windowEnd: windowEnd,
            category: taxonomy.category,
            confidence: taxonomy.confidence,
            categoryScores: taxonomy.scores,
            topYamnetScores: taxonomy.topYamnetScores,
            inferenceMs: stopwatch.elapsedMilliseconds,
          );
          _latestFrame = frame;
          _lastInferenceAt = DateTime.now();
          _inferenceCount++;
          _history.add(frame);
          final activity = _sourceActivityTracker.add(frame);
          _publishSourceActivity(activity);
          if (!_resultController.isClosed) {
            _resultController.add(frame);
          }
        } catch (error, stackTrace) {
          stopwatch.stop();
          _lastError = error.toString();
          AppLogger.error('YAMNet inference failed', error, stackTrace);
        }

        _inferenceBuffer.removeRange(0, hopSamples);
        _bufferStart = windowStart.add(
          const Duration(microseconds: 480000),
        );
      }
    } finally {
      _draining = false;
      if (_running && _inferenceBuffer.length >= inputWindowSamples) {
        _drainFuture = _drainInferenceWindows(_sessionGeneration);
      }
    }
  }

  void _trimBacklog() {
    while (_inferenceBuffer.length > maxBufferedPcmSamples) {
      _inferenceBuffer.removeRange(0, hopSamples);
      _bufferStart = (_bufferStart ?? DateTime.now()).add(
        const Duration(microseconds: 480000),
      );
      _droppedWindows++;
    }
  }

  void _resetSessionState({required bool clearHistory}) {
    _resampler.reset();
    _inferenceBuffer.clear();
    _bufferStart = null;
    _draining = false;
    if (clearHistory) {
      _history.clear();
      _latestFrame = null;
      _sourceActivityTracker.clear();
      _latestActivity = null;
    }
  }

  void _publishSourceActivity(SoundSourceActivitySnapshot activity) {
    // Source categories and timing may reveal private activity. Do not write
    // them to debug logs; optional history uses the encrypted local store.
    _latestActivity = activity;
    if (!_activityController.isClosed) {
      _activityController.add(activity);
    }
  }
}
