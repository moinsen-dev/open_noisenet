import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../core/database/models/audio_recording.dart';
import '../core/logging/app_logger.dart';

/// Comprehensive audio player widget with visualization and controls
class AudioPlayerWidget extends StatefulWidget {
  final AudioRecording recording;
  final Function()? onClose;

  const AudioPlayerWidget({
    super.key,
    required this.recording,
    this.onClose,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget>
    with TickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  late AnimationController _waveformController;

  // Playback state
  bool _isLoading = true;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0;

  // Subscriptions
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  // File information
  int? _fileSize;
  String? _errorMessage;

  // Waveform simulation data
  List<double> _waveformData = [];
  Timer? _waveformTimer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    )..repeat(reverse: true);

    _generateWaveformData();
    _loadAudio();
  }

  @override
  void dispose() {
    _waveformController.dispose();
    _waveformTimer?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _generateWaveformData() {
    // Generate simulated waveform data for visualization
    final random = Random();
    _waveformData = List.generate(100, (index) => random.nextDouble());
  }

  Future<void> _loadAudio() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Check if file exists and get file size
      final file = File(widget.recording.filePath);
      if (!await file.exists()) {
        throw Exception('Audio file not found: ${widget.recording.filePath}');
      }

      _fileSize = await file.length();
      AppLogger.recording(
          'Loading audio file: ${widget.recording.filePath} ($_fileSize bytes)');

      // Try multiple methods to load the audio
      bool loaded = false;

      // Method 1: Direct file path
      try {
        await _audioPlayer.setFilePath(widget.recording.filePath);
        loaded = true;
        AppLogger.recording('Audio loaded using direct file path');
      } catch (e) {
        AppLogger.recording('Direct file path failed: $e');

        // Method 2: File URI
        try {
          await _audioPlayer.setAudioSource(
            AudioSource.uri(Uri.file(widget.recording.filePath)),
          );
          loaded = true;
          AppLogger.recording('Audio loaded using file URI');
        } catch (e2) {
          AppLogger.recording('File URI method failed: $e2');

          // Method 3: File bytes
          try {
            final bytes = await file.readAsBytes();
            await _audioPlayer.setAudioSource(
              AudioSource.uri(
                Uri.dataFromBytes(bytes, mimeType: 'audio/wav'),
              ),
            );
            loaded = true;
            AppLogger.recording('Audio loaded using file bytes');
          } catch (e3) {
            AppLogger.recording('File bytes method failed: $e3');
            throw Exception(
                'All audio loading methods failed. Last error: $e3');
          }
        }
      }

      if (loaded) {
        // Set up streams
        _durationSubscription = _audioPlayer.durationStream.listen((duration) {
          if (duration != null && mounted) {
            setState(() {
              _duration = duration;
            });
          }
        });

        _positionSubscription = _audioPlayer.positionStream.listen((position) {
          if (mounted) {
            setState(() {
              _position = position;
            });
          }
        });

        _playerStateSubscription =
            _audioPlayer.playerStateStream.listen((state) {
          if (mounted) {
            setState(() {
              _isPlaying = state.playing;
              _isLoading = state.processingState == ProcessingState.loading;
            });
          }
        });

        // Set initial volume
        await _audioPlayer.setVolume(_volume);

        AppLogger.recording('Audio player initialized successfully');
      }
    } catch (e) {
      AppLogger.recording('Failed to load audio: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _playPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        _waveformTimer?.cancel();
      } else {
        await _audioPlayer.play();
        _startWaveformAnimation();
      }
    } catch (e) {
      AppLogger.recording('Error in play/pause: $e');
      setState(() {
        _errorMessage = 'Playback error: $e';
      });
    }
  }

  Future<void> _stop() async {
    try {
      await _audioPlayer.stop();
      _waveformTimer?.cancel();
    } catch (e) {
      AppLogger.recording('Error stopping playback: $e');
    }
  }

  Future<void> _seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      AppLogger.recording('Error seeking: $e');
    }
  }

  void _startWaveformAnimation() {
    _waveformTimer?.cancel();
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }
      setState(() {
        // Animate waveform during playback
        final random = Random();
        for (int i = 0; i < _waveformData.length; i++) {
          _waveformData[i] = random.nextDouble();
        }
      });
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title
          if (widget.onClose != null) ...[
            Row(
              children: [
                Icon(Icons.headset, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Noise Event Recording',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Metadata information
          _buildMetadataSection(theme, colorScheme),

          const SizedBox(height: 16),

          // Error message
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error, color: colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Waveform visualization
          _buildWaveformVisualization(theme, colorScheme),

          const SizedBox(height: 16),

          // Progress bar and time
          _buildProgressSection(theme, colorScheme),

          const SizedBox(height: 24),

          // Playback controls
          _buildPlaybackControls(theme, colorScheme),

          const SizedBox(height: 24),

          // Volume control
          _buildVolumeControl(theme, colorScheme),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMetadataSection(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recording Details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Use Wrap to prevent overflow
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildMetadataItem(
                'Duration',
                '${widget.recording.durationSeconds}s',
                Icons.timer,
                theme,
              ),
              _buildMetadataItem(
                'File Size',
                _fileSize != null
                    ? '${(_fileSize! / 1024).toStringAsFixed(1)} KB'
                    : 'Unknown',
                Icons.storage,
                theme,
              ),
              _buildMetadataItem(
                'Sample Rate',
                '${widget.recording.sampleRate} Hz',
                Icons.graphic_eq,
                theme,
              ),
              _buildMetadataItem(
                'Format',
                widget.recording.format.toUpperCase(),
                Icons.audiotrack,
                theme,
              ),
              if (widget.recording.avgLevel != null)
                _buildMetadataItem(
                  'Avg Level',
                  '${widget.recording.avgLevel!.toStringAsFixed(1)} dB',
                  Icons.equalizer,
                  theme,
                ),
              if (widget.recording.peakLevel != null)
                _buildMetadataItem(
                  'Peak Level',
                  '${widget.recording.peakLevel!.toStringAsFixed(1)} dB',
                  Icons.show_chart,
                  theme,
                ),
              if (widget.recording.triggerType != null)
                _buildMetadataItem(
                  'Trigger Type',
                  widget.recording.triggerType!
                      .replaceAll('_', ' ')
                      .toUpperCase(),
                  Icons.sensors,
                  theme,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataItem(
      String label, String value, IconData icon, ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100, maxWidth: 150),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveformVisualization(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.graphic_eq, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: CustomPaint(
              painter: WaveformPainter(
                data: _waveformData,
                progress: _duration.inMilliseconds > 0
                    ? _position.inMilliseconds / _duration.inMilliseconds
                    : 0.0,
                color: colorScheme.primary,
                backgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
                isPlaying: _isPlaying,
              ),
              child: Container(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: _duration.inMilliseconds > 0
                ? _position.inMilliseconds / _duration.inMilliseconds
                : 0.0,
            onChanged: _isLoading
                ? null
                : (value) {
                    final position = Duration(
                      milliseconds: (value * _duration.inMilliseconds).round(),
                    );
                    _seekTo(position);
                  },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(_position),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            Text(
              _formatDuration(_duration),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaybackControls(ThemeData theme, ColorScheme colorScheme) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        // Skip back 10 seconds
        IconButton(
          onPressed: _isLoading
              ? null
              : () {
                  final newPosition = _position - const Duration(seconds: 10);
                  _seekTo(newPosition < Duration.zero
                      ? Duration.zero
                      : newPosition);
                },
          icon: const Icon(Icons.replay_10),
          tooltip: 'Skip back 10s',
        ),

        // Stop button
        IconButton(
          onPressed: _isLoading ? null : _stop,
          icon: const Icon(Icons.stop),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.errorContainer,
            foregroundColor: colorScheme.onErrorContainer,
          ),
          tooltip: 'Stop',
        ),

        // Play/Pause button (larger)
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primary,
          ),
          child: IconButton(
            onPressed: _isLoading ? null : _playPause,
            icon: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(colorScheme.onPrimary),
                    ),
                  )
                : Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            iconSize: 32,
            style: IconButton.styleFrom(
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.all(16),
            ),
            tooltip: _isPlaying ? 'Pause' : 'Play',
          ),
        ),

        // Replay button
        IconButton(
          onPressed: _isLoading ? null : () => _seekTo(Duration.zero),
          icon: const Icon(Icons.replay),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.onSecondaryContainer,
          ),
          tooltip: 'Restart',
        ),

        // Skip forward 10 seconds
        IconButton(
          onPressed: _isLoading
              ? null
              : () {
                  final newPosition = _position + const Duration(seconds: 10);
                  _seekTo(newPosition > _duration ? _duration : newPosition);
                },
          icon: const Icon(Icons.forward_10),
          tooltip: 'Skip forward 10s',
        ),
      ],
    );
  }

  Widget _buildVolumeControl(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(Icons.volume_down,
            color: colorScheme.onSurface.withValues(alpha: 0.6)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
            ),
            child: Slider(
              value: _volume,
              min: 0.0,
              max: 1.0,
              onChanged: (value) async {
                setState(() {
                  _volume = value;
                });
                await _audioPlayer.setVolume(value);
              },
            ),
          ),
        ),
        Icon(Icons.volume_up,
            color: colorScheme.onSurface.withValues(alpha: 0.6)),
      ],
    );
  }
}

/// Custom painter for waveform visualization
class WaveformPainter extends CustomPainter {
  final List<double> data;
  final double progress;
  final Color color;
  final Color backgroundColor;
  final bool isPlaying;

  WaveformPainter({
    required this.data,
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final barWidth = size.width / data.length;

    for (int i = 0; i < data.length; i++) {
      final barHeight = data[i] * size.height * 0.8;
      final x = i * barWidth + barWidth / 2;
      final y1 = (size.height - barHeight) / 2;
      final y2 = y1 + barHeight;

      // Use progress color for bars that have been played
      final useProgressColor = (i / data.length) < progress;

      canvas.drawLine(
        Offset(x, y1),
        Offset(x, y2),
        useProgressColor ? progressPaint : paint,
      );
    }

    // Draw progress line
    if (progress > 0) {
      final progressX = size.width * progress;
      canvas.drawLine(
        Offset(progressX, 0),
        Offset(progressX, size.height),
        Paint()
          ..color = color.withValues(alpha: 0.7)
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.data != data;
  }
}
