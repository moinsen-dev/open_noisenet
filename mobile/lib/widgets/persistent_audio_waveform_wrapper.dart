import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../services/audio_capture_service.dart';
import 'audio_waveform_widget.dart';

class PersistentAudioWaveformWrapper extends StatefulWidget {
  final bool isActive;
  final double width;
  final double height;

  const PersistentAudioWaveformWrapper({
    super.key,
    required this.isActive,
    this.width = 300,
    this.height = 100,
  });

  @override
  State<PersistentAudioWaveformWrapper> createState() => _PersistentAudioWaveformWrapperState();
}

class _PersistentAudioWaveformWrapperState extends State<PersistentAudioWaveformWrapper> {
  final AudioCaptureService _audioCaptureService = GetIt.instance<AudioCaptureService>();
  AudioWaveformWidget? _waveformWidget;
  StreamController<double>? _proxySplController;
  StreamSubscription<double>? _sourceSubscription;
  
  @override
  void initState() {
    super.initState();
    _initializeProxyStream();
  }

  void _initializeProxyStream() {
    _proxySplController = StreamController<double>.broadcast();
    
    // Create the persistent waveform widget with our proxy stream
    _waveformWidget = AudioWaveformWidget(
      splStream: _proxySplController!.stream,
      width: widget.width,
      height: widget.height,
    );
    
    // Add a small delay to ensure the audio service is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateStreamConnection();
    });
  }

  void _updateStreamConnection() {
    if (widget.isActive) {
      _startForwarding();
    } else {
      _stopForwarding();
    }
  }

  void _startForwarding() {
    // Cancel any existing subscription
    _sourceSubscription?.cancel();
    
    debugPrint('🎵 PersistentAudioWaveformWrapper: Starting stream forwarding...');
    
    // Subscribe to the actual audio service stream and forward to proxy
    _sourceSubscription = _audioCaptureService.splStream.listen(
      (spl) {
        if (mounted && !_proxySplController!.isClosed) {
          _proxySplController!.add(spl);
          debugPrint('🎵 Forwarding SPL: ${spl.toStringAsFixed(1)} dB');
        }
      },
      onError: (Object error) {
        if (mounted && !_proxySplController!.isClosed) {
          _proxySplController!.addError(error);
          debugPrint('❌ Audio stream error: $error');
        }
      },
    );
    
    debugPrint('🎵 Stream forwarding subscription created');
  }

  void _stopForwarding() {
    _sourceSubscription?.cancel();
    _sourceSubscription = null;
    
    // Send zeros to indicate inactive state
    if (mounted && !_proxySplController!.isClosed) {
      _proxySplController!.add(0.0);
    }
  }

  @override
  void didUpdateWidget(PersistentAudioWaveformWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.isActive != widget.isActive) {
      _updateStreamConnection();
    }
  }

  @override
  void dispose() {
    _sourceSubscription?.cancel();
    _proxySplController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      // Show inactive state instead of removing the widget
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: widget.width,
            height: widget.height + 100, // Account for controls and labels
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mic_off,
                  size: 48,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Monitoring Inactive',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start monitoring to see real-time noise levels',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Return the persistent widget when active
    return _waveformWidget ?? const SizedBox.shrink();
  }
}