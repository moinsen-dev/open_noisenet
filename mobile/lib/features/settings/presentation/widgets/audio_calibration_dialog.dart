import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../services/reference_calibration_session.dart';
import '../../../../services/sound_analysis/sound_analysis_models.dart';

class AudioCalibrationDialog extends StatefulWidget {
  const AudioCalibrationDialog(
      {super.key,
      required this.frames,
      required this.captureReady,
      required this.initialOffset,
      required this.onSave});

  final Stream<PcmAudioFrame> frames;
  final bool Function() captureReady;
  final double initialOffset;
  final Future<void> Function(double) onSave;

  @override
  State<AudioCalibrationDialog> createState() => _AudioCalibrationDialogState();
}

class _AudioCalibrationDialogState extends State<AudioCalibrationDialog> {
  final _reference = TextEditingController();
  StreamSubscription<PcmAudioFrame>? _subscription;
  Timer? _watchdog;
  DateTime? _lastFrameAt;
  ReferenceCalibrationSession? _session;
  late double _offset = widget.initialOffset.clamp(-30, 30);
  String? _message;
  int _shownSeconds = 0;

  void _start() {
    if (!widget.captureReady()) {
      setState(
          () => _message = 'Start the sensor and wait for its sample rate.');
      return;
    }
    _subscription?.cancel();
    _watchdog?.cancel();
    final session = ReferenceCalibrationSession();
    setState(() {
      _session = session;
      _shownSeconds = 0;
      _message = null;
    });
    _subscription = widget.frames.listen((frame) {
      _lastFrameAt = DateTime.now();
      session.addFrame(frame);
      final seconds = session.elapsedSeconds.floor();
      if (session.error != null || session.isComplete) {
        _subscription?.cancel();
        _subscription = null;
        _watchdog?.cancel();
        _watchdog = null;
        if (mounted) {
          setState(() {
            _shownSeconds = seconds;
            _message = session.error ??
                'Comparison captured. Enter the reference LZeq.';
          });
        }
      } else if (seconds != _shownSeconds && mounted) {
        setState(() => _shownSeconds = seconds);
      }
    }, onError: (Object _) {
      _subscription?.cancel();
      _subscription = null;
      _watchdog?.cancel();
      _watchdog = null;
      if (mounted) setState(() => _message = 'Microphone comparison failed.');
    });
    _lastFrameAt = DateTime.now();
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (DateTime.now().difference(_lastFrameAt!) >
          const Duration(seconds: 3)) {
        _subscription?.cancel();
        _subscription = null;
        _watchdog?.cancel();
        _watchdog = null;
        if (mounted)
          setState(() => _message = 'Microphone data was interrupted.');
      }
    });
  }

  void _suggest() {
    final reference = double.tryParse(_reference.text.replaceAll(',', '.'));
    final suggestion =
        reference == null ? null : _session?.offsetForReference(reference);
    setState(() {
      if (suggestion == null) {
        _message =
            'Enter a valid reference and repeat if the signal was silent or clipped.';
      } else if (suggestion < -30 || suggestion > 30) {
        _message =
            'The suggested offset is outside the supported ±30 dB range.';
      } else {
        _offset = suggestion;
        _message =
            'Suggested offset applied. Verify at additional levels before saving.';
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _watchdog?.cancel();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Audio Calibration'),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'Compare with a calibrated, unweighted LZeq reference for the same 60 seconds. '
              'Audio is processed in memory only. Verify at several levels; an offset cannot correct frequency response.'),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: _subscription == null ? _start : null,
              child: const Text('Measure 60 seconds')),
          if (_session != null) Text('Measured: $_shownSeconds / 60 seconds'),
          TextField(
            controller: _reference,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Reference LZeq (dB)'),
          ),
          TextButton(
              onPressed: _session?.isComplete == true ? _suggest : null,
              child: const Text('Calculate offset')),
          if (_message != null) Text(_message!),
          Slider(
              value: _offset,
              min: -30,
              max: 30,
              divisions: 120,
              label: '${_offset.toStringAsFixed(1)} dB',
              onChanged: (value) => setState(() => _offset = value)),
          Text('Selected offset: ${_offset.toStringAsFixed(1)} dB'),
          const Text(
              'A broadband LAeq reference is not comparable to this unweighted measurement. '
              'This comparison does not certify the phone as a sound level meter.'),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () async {
                await widget.onSave(_offset);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save')),
        ],
      );
}
